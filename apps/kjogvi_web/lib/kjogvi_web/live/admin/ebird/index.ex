defmodule KjogviWeb.Live.Admin.Ebird.Index do
  @moduledoc """
  Admin index of the eBird regions dataset: every eBird country with its
  derived match status, subdivision link counts, and status filter chips —
  the "which countries are ready" dashboard. Each country links to its
  matching workbench (`Live.Admin.Ebird.Show`).
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @statuses [:matched, :matched_mixed, :matched_iso_extra, :partial, :unmatched]

  @impl true
  def mount(_params, _session, socket) do
    countries = Geo.Ebird.countries_with_statuses()

    {:ok,
     socket
     |> assign(:page_title, "eBird Locations")
     |> assign(:countries, countries)
     |> assign(:statuses, @statuses)
     |> assign(:status_counts, Enum.frequencies_by(countries, & &1.stats.status))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status = parse_status(params["status"])

    filtered =
      case status do
        nil -> socket.assigns.countries
        status -> Enum.filter(socket.assigns.countries, &(&1.stats.status == status))
      end

    {:noreply,
     socket
     |> assign(:status, status)
     |> assign(:filtered_countries, filtered)}
  end

  defp parse_status(nil), do: nil

  defp parse_status(param) do
    Enum.find(@statuses, &(Atom.to_string(&1) == param))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">
          eBird Locations
        </.h1>
        <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg mb-1">
          <span id="ebird-countries-count" class="text-lg font-header font-bold tracking-tight">
            {length(@countries)}
          </span>
          <span class="text-forest-100 text-sm font-medium">countries</span>
        </div>
      </div>

      <%!-- Status filter --%>
      <ul id="ebird-status-filter" class="flex flex-wrap gap-2">
        <.inline_filter_pill selected={@status == nil} href={~p"/admin/ebird"}>
          All ({length(@countries)})
        </.inline_filter_pill>
        <.inline_filter_pill
          :for={status <- @statuses}
          selected={@status == status}
          active={Map.get(@status_counts, status, 0) > 0}
          href={~p"/admin/ebird?status=#{status}"}
        >
          {ebird_status_label(status)} ({Map.get(@status_counts, status, 0)})
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
          class="px-4 py-2.5 flex flex-wrap items-center gap-x-3 gap-y-1"
        >
          <span class="font-mono text-sm text-stone-500 w-10 shrink-0">{country.code}</span>
          <.link
            navigate={~p"/admin/ebird/#{country.code}"}
            class="font-medium text-forest-700"
            phx-no-format
          >{country.name}</.link>
          <.ebird_status_badge status={stats.status} />
          <span :if={stats.sub1_total > 0} class="text-sm text-stone-500">
            {stats.sub1_linked}/{stats.sub1_total} subdivisions linked
          </span>
          <span
            :if={stats.iso_extra > 0}
            class="text-sm text-stone-500"
            title="ISO subdivisions with no eBird counterpart"
          >
            {stats.iso_extra} ISO-only
          </span>
        </li>
      </ul>

      <div :if={@filtered_countries == []} class="text-center py-8 text-stone-500">
        <p :if={@countries == []} class="text-lg font-medium">No eBird locations yet</p>
        <p :if={@countries == []} class="text-sm">
          Run the eBird regions import to seed the dataset.
        </p>
        <p :if={@countries != []} class="text-lg font-medium">
          No countries with this status
        </p>
      </div>
    </div>
    """
  end
end
