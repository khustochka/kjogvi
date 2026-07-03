defmodule KjogviWeb.Live.Admin.Imports.Locations.Index do
  @moduledoc """
  Operations page for the common locations dataset: restore from and dump to
  the configured `Kjogvi.Datasets` snapshot storage, plus the ISO 3166
  bootstrap import card.

  Restore and dump run through `Kjogvi.Server.ExclusiveTaskProcessor` (keys
  `{:geo_restore, :common}` / `{:geo_dump, :common}`), so a run cannot start
  twice and its status is shared across sessions: the page subscribes to both
  keys' PubSub topics, seeds from `get_status/1` on mount, and follows the
  lifecycle events live.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Datasets
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.Location
  alias Kjogvi.Server.ExclusiveTaskProcessor
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic
  alias KjogviWeb.Live.Admin.Imports

  @restore_key {:geo_restore, :common}
  @dump_key {:geo_dump, :common}

  # Counts are listed top level first; `special` sits outside the levels, last.
  @type_order (Location.hierarchy_levels() ++ [:special]) |> Enum.with_index() |> Map.new()

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(@restore_key))
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(@dump_key))
    end

    {:ok,
     socket
     |> assign(:page_title, "Location Imports")
     |> assign(:restore_result, ExclusiveTaskProcessor.get_status(@restore_key))
     |> assign(:dump_result, ExclusiveTaskProcessor.get_status(@dump_key))
     |> assign_dataset_state()}
  end

  @impl true
  def handle_event("start_restore", _params, socket) do
    ExclusiveTaskProcessor.start_task(
      @restore_key,
      fn _key -> Kjogvi.Geo.Restore.run(:common_locations) end,
      message: "Restoring common locations..."
    )

    {:noreply,
     assign(
       socket,
       :restore_result,
       AsyncResult.loading(%{message: "Restoring common locations..."})
     )}
  end

  def handle_event("start_dump", _params, socket) do
    ExclusiveTaskProcessor.start_task(
      @dump_key,
      fn _key -> Dump.run(:common_locations) end,
      message: "Dumping common locations..."
    )

    {:noreply,
     assign(socket, :dump_result, AsyncResult.loading(%{message: "Dumping common locations..."}))}
  end

  # Lifecycle events carry the AsyncResult exactly as the processor stores it.
  # A finished run changes what the cards report (counts, snapshot age), so a
  # terminal `:ok` refreshes the dataset state.
  @impl true
  def handle_info({:lifecycle, event, @restore_key, async_result}, socket) do
    {:noreply,
     socket
     |> assign(:restore_result, async_result)
     |> maybe_refresh_dataset_state(event)}
  end

  def handle_info({:lifecycle, event, @dump_key, async_result}, socket) do
    {:noreply,
     socket
     |> assign(:dump_result, async_result)
     |> maybe_refresh_dataset_state(event)}
  end

  # Mid-task progress broadcasts (neither task emits them today).
  def handle_info({:progress, _key, _status}, socket), do: {:noreply, socket}

  defp maybe_refresh_dataset_state(socket, :ok), do: assign_dataset_state(socket)
  defp maybe_refresh_dataset_state(socket, _event), do: socket

  defp assign_dataset_state(socket) do
    socket
    |> assign(:counts, ordered_counts())
    |> assign(:snapshot_modified_at, snapshot_modified_at())
  end

  defp ordered_counts do
    Geo.common_location_counts_by_type()
    |> Enum.sort_by(fn {type, _count} -> Map.fetch!(@type_order, type) end)
  end

  defp snapshot_modified_at do
    case Datasets.last_modified(Dump.storage_key(:common_locations)) do
      {:ok, modified_at} -> modified_at
      {:error, _} -> nil
    end
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

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>Location Imports</.h1>

    <div class="lg:grid lg:grid-cols-2 lg:gap-6 lg:items-start">
      <section
        id="restore-common-locations"
        class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0"
      >
        <.h2 class="mb-4!">Restore Common Locations</.h2>

        <ul class="text-sm text-slate-700 mb-4 space-y-1">
          <li :for={{type, count} <- @counts}>{Phoenix.Naming.humanize(type)}: {count}</li>
          <li :if={@counts == []}>No common locations yet.</li>
        </ul>

        <%= if @snapshot_modified_at do %>
          <p class="text-sm text-slate-700 mb-4">
            Snapshot from {format_timestamp(@snapshot_modified_at)}.
          </p>
          <.form id="restore-common-locations-form" for={nil} phx-submit="start_restore">
            <.button disabled={loading?(@restore_result)}>
              {if loading?(@restore_result), do: "Restoring…", else: "Restore"}
            </.button>
          </.form>
        <% else %>
          <p id="restore-no-snapshot" class="text-sm text-amber-700">
            No snapshot available to restore from.
          </p>
        <% end %>

        <.status_line
          id="restore-common-locations-status"
          status={status(@restore_result, "Restore")}
        />
      </section>

      <section id="dump-common-locations" class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
        <.h2 class="mb-4!">Dump Common Locations</.h2>

        <p class="text-sm text-slate-700 mb-4">
          <%= if @snapshot_modified_at do %>
            Current snapshot from {format_timestamp(@snapshot_modified_at)}. Dumping replaces it.
          <% else %>
            No snapshot yet.
          <% end %>
        </p>

        <%= if @counts == [] do %>
          <p id="dump-no-locations" class="text-sm text-amber-700">
            Nothing to dump: there are no common locations.
          </p>
        <% else %>
          <.form id="dump-common-locations-form" for={nil} phx-submit="start_dump">
            <.button disabled={loading?(@dump_result)}>
              {if loading?(@dump_result), do: "Dumping…", else: "Dump"}
            </.button>
          </.form>
        <% end %>

        <.status_line id="dump-common-locations-status" status={status(@dump_result, "Dump")} />
      </section>

      <section id="iso-import" class="border border-slate-300 rounded-lg p-6 mb-8 lg:mb-0">
        <.h2 class="mb-4!">ISO 3166 Import</.h2>
        <.live_component module={Imports.Locations.Iso} id="locations-import" />
      </section>
    </div>
    """
  end
end
