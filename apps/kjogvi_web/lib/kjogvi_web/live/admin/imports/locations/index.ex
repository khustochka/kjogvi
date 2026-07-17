defmodule KjogviWeb.Live.Admin.Imports.Locations.Index do
  @moduledoc """
  Operations page for the geo datasets (common locations and eBird locations):
  restore from and dump to the configured `Kjogvi.Datasets` snapshot storage,
  plus the ISO 3166 bootstrap import card.

  Restore and dump run through `Kjogvi.Server.ExclusiveTaskProcessor` (keys
  `{:geo_restore, :common | :ebird}` / `{:geo_dump, :common | :ebird}`), so a
  run cannot start twice and its status is shared across sessions: the page
  subscribes to every key's PubSub topic, seeds from `get_status/1` on mount,
  and follows the lifecycle events live.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Datasets
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Server.ExclusiveTaskProcessor
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic
  alias KjogviWeb.Live.Admin.Imports

  @task_keys %{
    restore: %{
      common_locations: {:geo_restore, :common},
      ebird_locations: {:geo_restore, :ebird}
    },
    dump: %{
      common_locations: {:geo_dump, :common},
      ebird_locations: {:geo_dump, :ebird}
    }
  }

  @datasets Map.keys(@task_keys.restore)

  # Reverse lookup for the lifecycle events: task key => {op, dataset}.
  @task_slots for {op, keys} <- @task_keys,
                  {dataset, key} <- keys,
                  into: %{},
                  do: {key, {op, dataset}}

  # Counts are listed top level first; `special` sits outside the levels, last.
  @type_order (Location.hierarchy_levels() ++ [:special]) |> Enum.with_index() |> Map.new()

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      for {key, _slot} <- @task_slots do
        Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
      end
    end

    {:ok,
     socket
     |> assign(:page_title, "Location Imports")
     |> assign(:restore_results, task_statuses(:restore))
     |> assign(:dump_results, task_statuses(:dump))
     |> assign_dataset_state()}
  end

  @impl true
  def handle_event("start_restore", %{"dataset" => dataset}, socket) do
    dataset = parse_dataset(dataset)
    message = "Restoring #{dataset_label(dataset)}..."

    ExclusiveTaskProcessor.start_task(
      @task_keys.restore[dataset],
      fn _key -> Kjogvi.Geo.Restore.run(dataset) end,
      message: message
    )

    {:noreply,
     update(
       socket,
       :restore_results,
       &Map.put(&1, dataset, AsyncResult.loading(%{message: message}))
     )}
  end

  def handle_event("start_dump", %{"dataset" => dataset}, socket) do
    dataset = parse_dataset(dataset)
    message = "Dumping #{dataset_label(dataset)}..."

    ExclusiveTaskProcessor.start_task(
      @task_keys.dump[dataset],
      fn _key -> Dump.run(dataset) end,
      message: message
    )

    {:noreply,
     update(
       socket,
       :dump_results,
       &Map.put(&1, dataset, AsyncResult.loading(%{message: message}))
     )}
  end

  # Lifecycle events carry the AsyncResult exactly as the processor stores it.
  # A finished run changes what the cards report (counts, snapshot age), so a
  # terminal `:ok` refreshes the dataset state.
  @impl true
  def handle_info({:lifecycle, event, key, async_result}, socket) do
    socket =
      case @task_slots[key] do
        {:restore, dataset} ->
          update(socket, :restore_results, &Map.put(&1, dataset, async_result))

        {:dump, dataset} ->
          update(socket, :dump_results, &Map.put(&1, dataset, async_result))

        nil ->
          socket
      end

    {:noreply, maybe_refresh_dataset_state(socket, event)}
  end

  # Mid-task progress broadcasts (none of the tasks emit them today).
  def handle_info({:progress, _key, _status}, socket), do: {:noreply, socket}

  defp maybe_refresh_dataset_state(socket, :ok), do: assign_dataset_state(socket)
  defp maybe_refresh_dataset_state(socket, _event), do: socket

  defp task_statuses(op) do
    Map.new(@task_keys[op], fn {dataset, key} ->
      {dataset, ExclusiveTaskProcessor.get_status(key)}
    end)
  end

  defp parse_dataset("common_locations"), do: :common_locations
  defp parse_dataset("ebird_locations"), do: :ebird_locations

  defp dataset_label(:common_locations), do: "common locations"
  defp dataset_label(:ebird_locations), do: "eBird locations"

  defp assign_dataset_state(socket) do
    socket
    |> assign(:counts, ordered_counts())
    |> assign(:ebird_stats, ebird_stats())
    |> assign(
      :snapshot_states,
      Map.new(@datasets, &{&1, Datasets.snapshot_status(Dump.storage_key(&1))})
    )
  end

  defp ordered_counts do
    Geo.common_location_counts_by_type()
    |> Enum.sort_by(fn {type, _count} -> Map.fetch!(@type_order, type) end)
  end

  defp ebird_stats do
    by_type = Geo.Ebird.location_counts_by_type()

    counts =
      EbirdLocation.location_types()
      |> Enum.flat_map(fn type ->
        case by_type[type] do
          nil -> []
          stats -> [{type, stats}]
        end
      end)

    %{
      counts: counts,
      total: counts |> Enum.map(fn {_type, %{total: n}} -> n end) |> Enum.sum(),
      matched: counts |> Enum.map(fn {_type, %{matched: n}} -> n end) |> Enum.sum()
    }
  end

  defp loading?(%AsyncResult{loading: loading}), do: not is_nil(loading)

  # The card's status line: what the tracked task is doing or how it ended.
  defp status(%AsyncResult{} = async_result, verb) do
    cond do
      async_result.failed ->
        {:error, "#{verb} failed: #{reason_message(async_result.failed)}"}

      async_result.loading ->
        {:loading, Map.get(async_result.loading, :message, "In progress...")}

      async_result.ok? ->
        {:ok, "#{verb} finished: #{async_result.result} rows."}

      true ->
        nil
    end
  end

  defp reason_message(:enoent), do: "no snapshot found."
  defp reason_message(:timeout), do: "timeout."

  defp reason_message({:user_owned_id_collision, ids}),
    do: "snapshot ids collide with user-owned locations: #{inspect(ids)}."

  defp reason_message(reason), do: inspect(reason)

  defp format_timestamp(%DateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%d %H:%M:%S UTC")

  attr :id, :string, required: true
  attr :status, :any, required: true

  defp status_line(assigns) do
    ~H"""
    <p id={@id} aria-live="polite" class={["mt-4 text-sm", status_class(@status)]}>
      <%= case @status do %>
        <% {_kind, text} -> %>
          {text}
        <% nil -> %>
      <% end %>
    </p>
    """
  end

  defp status_class({:error, _}), do: "text-red-700"
  defp status_class({:ok, _}), do: "text-green-700"
  defp status_class({:loading, _}), do: "text-slate-600"
  defp status_class(nil), do: nil

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :dataset, :atom, required: true
  attr :snapshot_state, :any, required: true
  attr :result, :any, required: true
  slot :inner_block, doc: "the dataset's current counts"

  defp restore_card(assigns) do
    ~H"""
    <section id={@id} class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
      <.h2 class="mb-4!">{@title}</.h2>

      {render_slot(@inner_block)}

      <%= case @snapshot_state do %>
        <% {:ok, modified_at} -> %>
          <p class="text-sm text-slate-700 mb-4">
            Snapshot from {format_timestamp(modified_at)}.
          </p>
          <.form id={"#{@id}-form"} for={nil} phx-submit="start_restore">
            <input type="hidden" name="dataset" value={@dataset} />
            <.button disabled={loading?(@result)}>
              {if loading?(@result), do: "Restoring…", else: "Restore"}
            </.button>
          </.form>
        <% :none -> %>
          <p id={"#{@id}-no-snapshot"} class="text-sm text-amber-700">
            No snapshot available to restore from.
          </p>
        <% :not_configured -> %>
          <p id={"#{@id}-storage-not-configured"} class="text-sm text-amber-700">
            Snapshot storage is not configured.
          </p>
        <% {:error, _reason} -> %>
          <p id={"#{@id}-snapshot-check-failed"} class="text-sm text-amber-700">
            Checking snapshot storage failed.
          </p>
      <% end %>

      <.status_line id={"#{@id}-status"} status={status(@result, "Restore")} />
    </section>
    """
  end

  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :dataset, :atom, required: true
  attr :snapshot_state, :any, required: true
  attr :result, :any, required: true
  attr :empty, :boolean, required: true, doc: "whether the dataset has no rows to dump"
  attr :empty_notice, :string, required: true

  defp dump_card(assigns) do
    ~H"""
    <section id={@id} class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
      <.h2 class="mb-4!">{@title}</.h2>

      <%= if @snapshot_state == :not_configured do %>
        <p id={"#{@id}-storage-not-configured"} class="text-sm text-amber-700">
          Snapshot storage is not configured.
        </p>
      <% else %>
        <p class="text-sm text-slate-700 mb-4">
          <%= case @snapshot_state do %>
            <% {:ok, modified_at} -> %>
              Current snapshot from {format_timestamp(modified_at)}. Dumping replaces it.
            <% :none -> %>
              No snapshot yet.
            <% {:error, _reason} -> %>
              Checking for an existing snapshot failed.
          <% end %>
        </p>

        <%= if @empty do %>
          <p id={"#{@id}-empty"} class="text-sm text-amber-700">
            {@empty_notice}
          </p>
        <% else %>
          <.form id={"#{@id}-form"} for={nil} phx-submit="start_dump">
            <input type="hidden" name="dataset" value={@dataset} />
            <.button disabled={loading?(@result)}>
              {if loading?(@result), do: "Dumping…", else: "Dump"}
            </.button>
          </.form>
        <% end %>
      <% end %>

      <.status_line id={"#{@id}-status"} status={status(@result, "Dump")} />
    </section>
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.section_nav class="mb-6">
      <:item href={~p"/admin/locations"}>Common</:item>
      <:item href={~p"/admin/ebird/locations"}>eBird</:item>
      <:item href={~p"/admin/imports/locations"} current>Imports</:item>
    </.section_nav>

    <.h1>Location Imports</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-start">
      <.restore_card
        id="restore-common-locations"
        title="Restore Common Locations"
        dataset={:common_locations}
        snapshot_state={@snapshot_states.common_locations}
        result={@restore_results.common_locations}
      >
        <ul class="text-sm text-slate-700 mb-4 space-y-1">
          <li :for={{type, count} <- @counts}>{Phoenix.Naming.humanize(type)}: {count}</li>
          <li :if={@counts == []}>No common locations yet.</li>
        </ul>
      </.restore_card>

      <.dump_card
        id="dump-common-locations"
        title="Dump Common Locations"
        dataset={:common_locations}
        snapshot_state={@snapshot_states.common_locations}
        result={@dump_results.common_locations}
        empty={@counts == []}
        empty_notice="Nothing to dump: there are no common locations."
      />

      <.restore_card
        id="restore-ebird-locations"
        title="Restore eBird Locations"
        dataset={:ebird_locations}
        snapshot_state={@snapshot_states.ebird_locations}
        result={@restore_results.ebird_locations}
      >
        <ul class="text-sm text-slate-700 mb-4 space-y-1">
          <li :for={{type, %{total: total, matched: matched}} <- @ebird_stats.counts}>
            {Phoenix.Naming.humanize(type)}: {total} ({matched} matched)
          </li>
          <li :if={@ebird_stats.counts == []}>No eBird locations yet.</li>
          <li :if={@ebird_stats.counts != []}>
            Matched: {@ebird_stats.matched} of {@ebird_stats.total}
          </li>
        </ul>
      </.restore_card>

      <.dump_card
        id="dump-ebird-locations"
        title="Dump eBird Locations"
        dataset={:ebird_locations}
        snapshot_state={@snapshot_states.ebird_locations}
        result={@dump_results.ebird_locations}
        empty={@ebird_stats.counts == []}
        empty_notice="Nothing to dump: there are no eBird locations."
      />
    </div>

    <.h2 id="initial-imports" class="mt-4 mb-4">Initial Imports</.h2>
    <p class="text-sm text-slate-700 mb-6">
      Bootstrap tools that fill the tables from the raw sources; the curated
      snapshots above are the usual seed path.
    </p>

    <div class="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-start">
      <section id="iso-import" class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
        <.h2 class="mb-4!">ISO 3166 Import</.h2>
        <.live_component module={Imports.Locations.Iso} id="locations-import" />
      </section>

      <section id="ebird-import" class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
        <.h2 class="mb-4!">eBird Regions Import</.h2>
        <.live_component module={Imports.Locations.Ebird} id="ebird-regions-import" />
      </section>

      <section id="changelog-apply" class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
        <.h2 class="mb-4!">Common Locations Changelog</.h2>
        <.live_component module={Imports.Locations.Changelog} id="locations-changelog-apply" />
      </section>
    </div>
    """
  end
end
