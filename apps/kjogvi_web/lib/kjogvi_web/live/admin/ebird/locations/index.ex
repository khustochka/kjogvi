defmodule KjogviWeb.Live.Admin.Ebird.Locations.Index do
  @moduledoc """
  Admin index of the eBird regions dataset: every eBird country with its
  derived match status, subdivision link counts, and status filter chips —
  the "which countries are ready" dashboard. Each country links to its
  matching workbench (`Live.Admin.Ebird.Locations.Show`).

  Carries the bulk code pass (`Geo.Ebird.match_all/0`, run via `start_async`):
  one button links every country by code and every perfect-match country's
  subdivisions, then reloads the statuses.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Util.Number

  @statuses [:matched, :iso_extra, :ebird_only_subregions, :name_candidate, :ebird_only, :mixed]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "eBird Locations")
     |> assign(:statuses, @statuses)
     |> assign(:running_bulk, false)
     |> load_countries()}
  end

  defp load_countries(socket) do
    countries = Geo.Ebird.countries_with_statuses()

    total_locations =
      Geo.Ebird.location_counts_by_type()
      |> Map.values()
      |> Enum.reduce(0, &(&1.total + &2))

    socket
    |> assign(:countries, countries)
    |> assign(:total_locations, total_locations)
    |> assign(:status_counts, Enum.frequencies_by(countries, & &1.stats.status))
    |> assign(:incomplete_count, Enum.count(countries, &(not fully_linked?(&1.stats))))
    |> assign(:sub2_count, Enum.count(countries, &(&1.stats.sub2_total > 0)))
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket
     |> assign(:status, parse_status(params["status"]))
     |> assign(:only_incomplete, params["work"] == "incomplete")
     |> assign(:only_sub2, params["sub2"] == "present")
     |> apply_filters()}
  end

  # Recomputes `@filtered_countries` from `@countries` and the current filter
  # assigns — used both on `handle_params` and after the bulk pass reloads.
  defp apply_filters(socket) do
    filtered =
      socket.assigns.countries
      |> filter_by_status(socket.assigns.status)
      |> filter_by_completeness(socket.assigns.only_incomplete)
      |> filter_by_sub2(socket.assigns.only_sub2)

    assign(socket, :filtered_countries, filtered)
  end

  @impl true
  def handle_event("run_bulk_match", _params, socket) do
    {:noreply,
     socket
     |> clear_flash()
     |> assign(:running_bulk, true)
     |> start_async(:bulk_match, fn -> Geo.Ebird.match_all() end)}
  end

  @impl true
  def handle_async(:bulk_match, {:ok, summary}, socket) do
    {:noreply,
     socket
     |> assign(:running_bulk, false)
     |> load_countries()
     |> apply_filters()
     |> put_flash(
       :info,
       "Linked #{summary.countries} countries and #{summary.subdivisions} subdivisions " <>
         "across #{summary.matched} fully-matched countries."
     )}
  end

  def handle_async(:bulk_match, {:exit, reason}, socket) do
    {:noreply,
     socket
     |> assign(:running_bulk, false)
     |> put_flash(:error, "Bulk match crashed: #{inspect(reason)}")}
  end

  defp filter_by_status(countries, nil), do: countries

  defp filter_by_status(countries, status) do
    Enum.filter(countries, &(&1.stats.status == status))
  end

  defp filter_by_completeness(countries, false), do: countries

  defp filter_by_completeness(countries, true) do
    Enum.filter(countries, &(not fully_linked?(&1.stats)))
  end

  defp filter_by_sub2(countries, false), do: countries

  defp filter_by_sub2(countries, true) do
    Enum.filter(countries, &(&1.stats.sub2_total > 0))
  end

  defp parse_status(nil), do: nil

  defp parse_status(param) do
    Enum.find(@statuses, &(Atom.to_string(&1) == param))
  end

  # Mirrors `EbirdLocation.Query.fully_linked?/1`: every eBird row linked. The
  # complement is the "still has subdivisions to link" work queue.
  defp fully_linked?(stats) do
    stats.sub1_linked == stats.sub1_total and (stats.country_linked or stats.sub1_total > 0)
  end

  # Query string preserving the other filter dimensions, so the chip rows
  # compose instead of resetting each other.
  defp filter_params(status, only_incomplete, only_sub2) do
    []
    |> maybe_put(:status, status && Atom.to_string(status))
    |> maybe_put(:work, only_incomplete && "incomplete")
    |> maybe_put(:sub2, only_sub2 && "present")
  end

  defp maybe_put(params, _key, nil), do: params
  defp maybe_put(params, _key, false), do: params
  defp maybe_put(params, key, value), do: params ++ [{key, value}]

  defp bulk_match_label(true), do: "Matching…"
  defp bulk_match_label(false), do: "Run bulk match"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_nav>
        <:item href={~p"/admin/locations"}>Common</:item>
        <:item href={~p"/admin/ebird/locations"} current>eBird</:item>
        <:item href={~p"/admin/imports/locations"}>Imports</:item>
      </.section_nav>

      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">
          eBird Locations
        </.h1>
        <div class="flex flex-wrap items-stretch gap-3 mb-1">
          <.button
            :if={@countries != []}
            id="run-bulk-match-button"
            phx-click="run_bulk_match"
            disabled={@running_bulk}
            data-confirm="Link every eBird country by code and every perfectly-matched country's subdivisions? Existing links are left untouched."
            class="flex items-center"
          >
            {bulk_match_label(@running_bulk)}
          </.button>
          <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg">
            <span id="ebird-countries-count" class="text-lg font-header font-bold tracking-tight">
              {length(@countries)}
            </span>
            <span class="text-forest-100 text-sm font-medium">countries</span>
          </div>
          <div class="inline-flex items-baseline gap-2 bg-stone-700 text-white px-3 py-2 rounded-lg">
            <span id="ebird-locations-count" class="text-lg font-header font-bold tracking-tight">
              {Number.delimit(@total_locations)}
            </span>
            <span class="text-stone-300 text-sm font-medium">locations</span>
          </div>
        </div>
      </div>

      <%!-- Completeness filter: the "what still needs linking" work queue --%>
      <ul id="ebird-work-filter" class="flex flex-wrap items-baseline gap-2">
        <li class="text-sm font-medium text-stone-500 mr-1">Show</li>
        <.inline_filter_pill
          selected={not @only_incomplete}
          href={~p"/admin/ebird/locations?#{filter_params(@status, false, @only_sub2)}"}
        >
          All ({length(@countries)})
        </.inline_filter_pill>
        <.inline_filter_pill
          selected={@only_incomplete}
          active={@incomplete_count > 0}
          href={~p"/admin/ebird/locations?#{filter_params(@status, true, @only_sub2)}"}
        >
          Not fully linked ({@incomplete_count})
        </.inline_filter_pill>
      </ul>

      <%!-- Status filter --%>
      <ul id="ebird-status-filter" class="flex flex-wrap items-baseline gap-2">
        <li class="text-sm font-medium text-stone-500 mr-1">Status</li>
        <.inline_filter_pill
          selected={@status == nil}
          href={~p"/admin/ebird/locations?#{filter_params(nil, @only_incomplete, @only_sub2)}"}
        >
          All ({length(@countries)})
        </.inline_filter_pill>
        <.inline_filter_pill
          :for={status <- @statuses}
          selected={@status == status}
          active={Map.get(@status_counts, status, 0) > 0}
          href={~p"/admin/ebird/locations?#{filter_params(status, @only_incomplete, @only_sub2)}"}
        >
          {ebird_status_label(status)} ({Map.get(@status_counts, status, 0)})
        </.inline_filter_pill>
      </ul>

      <%!-- Subdivision2 filter --%>
      <ul id="ebird-sub2-filter" class="flex flex-wrap items-baseline gap-2">
        <li class="text-sm font-medium text-stone-500 mr-1">Subdivision2</li>
        <.inline_filter_pill
          selected={not @only_sub2}
          href={~p"/admin/ebird/locations?#{filter_params(@status, @only_incomplete, false)}"}
        >
          All ({length(@countries)})
        </.inline_filter_pill>
        <.inline_filter_pill
          selected={@only_sub2}
          active={@sub2_count > 0}
          href={~p"/admin/ebird/locations?#{filter_params(@status, @only_incomplete, true)}"}
        >
          With subdivision2 ({@sub2_count})
        </.inline_filter_pill>
      </ul>

      <%!-- Countries --%>
      <ul
        :if={@filtered_countries != []}
        class="border border-stone-200 rounded-lg divide-y divide-stone-100"
      >
        <li
          :for={%{ebird_location: country, stats: stats} <- @filtered_countries}
          id={"ebird-country-#{country.code}"}
          class={[
            "px-4 py-2.5 flex flex-wrap items-center gap-x-3 gap-y-1",
            fully_linked?(stats) && "bg-forest-50"
          ]}
        >
          <span class="font-mono text-sm text-stone-500 w-10 shrink-0">{country.code}</span>
          <.link
            navigate={~p"/admin/ebird/locations/#{country.code}"}
            class="font-medium text-forest-700"
            phx-no-format
          >{country.name}</.link>
          <.ebird_status_badge status={stats.status} />
          <span :if={stats.sub1_total > 0} class="text-sm text-stone-500">
            {stats.sub1_linked}/{stats.sub1_total} subdivisions linked
          </span>
          <span
            :if={stats.sub2_total > 0}
            class={[
              "text-sm",
              (stats.sub2_linked == stats.sub2_total && "text-forest-600") || "text-stone-500"
            ]}
            title="eBird subdivision2 regions imported as common locations"
          >
            {Number.delimit(stats.sub2_linked)}/{Number.delimit(stats.sub2_total)} sub2 imported
          </span>
          <span
            :if={stats.iso_extra > 0 and stats.sub1_total > 0}
            class="text-sm text-stone-500"
            title="ISO subdivisions with no eBird counterpart"
          >
            {stats.iso_extra} ISO-only
          </span>
          <%!-- eBird models the country as one unit: its ISO subdivisions are
          context, not work left over. --%>
          <span
            :if={stats.iso_extra > 0 and stats.sub1_total == 0}
            class="text-sm text-stone-400"
            title="eBird has no subdivisions for this country; ISO does"
          >
            {stats.iso_extra} in ISO only
          </span>
          <span :if={country.location} class="ml-auto flex items-center gap-1 text-sm">
            <span class="text-stone-400">&rarr;</span>
            <.link
              navigate={~p"/admin/locations/#{country.location.slug}"}
              class="text-forest-700"
              phx-no-format
            >{Location.long_name(:private, country.location)}</.link>
          </span>
        </li>
      </ul>

      <div :if={@filtered_countries == []} class="text-center py-8 text-stone-500">
        <p :if={@countries == []} class="text-lg font-medium">No eBird locations yet</p>
        <p :if={@countries == []} class="text-sm">
          Run the eBird regions import to seed the dataset.
        </p>
        <p :if={@countries != []} class="text-lg font-medium">
          No countries match these filters
        </p>
      </div>
    </div>
    """
  end
end
