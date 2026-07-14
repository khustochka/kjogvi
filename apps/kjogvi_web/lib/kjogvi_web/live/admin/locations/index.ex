defmodule KjogviWeb.Live.Admin.Locations.Index do
  @moduledoc """
  Admin index of the common locations dataset: the entire shared scaffold as a
  collapsible tree with text search, country rows carrying their eBird match
  status badge, and status filter chips — the "which countries are ready"
  dashboard. Unlike `Live.My.Locations.Index` it shows every common location —
  including countries nothing hangs under yet — and no personal locations.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @statuses [:matched, :iso_extra, :name_candidate, :ebird_only, :mixed]

  @impl true
  def mount(_params, _session, socket) do
    tree = Geo.common_location_tree()

    countries = for %{location: %{location_type: :country} = location} <- tree, do: location
    ebird_statuses = Geo.Ebird.statuses_for_common_countries(countries)

    status_counts =
      Enum.frequencies_by(countries, fn country ->
        case ebird_statuses[country.id] do
          nil -> :no_ebird
          entry -> entry.status
        end
      end)

    {:ok,
     socket
     |> assign(:page_title, "Common Locations")
     |> assign(:location_tree, tree)
     |> assign(:locations_count, count_nodes(tree))
     |> assign(:countries_count, length(countries))
     |> assign(:ebird_statuses, ebird_statuses)
     |> assign(:statuses, @statuses)
     |> assign(:status_counts, status_counts)
     |> assign(:search_term, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_params(params, _url, socket) do
    status = parse_status(params["status"])

    filtered =
      case status do
        nil ->
          socket.assigns.location_tree

        status ->
          Enum.filter(socket.assigns.location_tree, fn node ->
            node_status(node, socket.assigns.ebird_statuses) == status
          end)
      end

    {:noreply,
     socket
     |> assign(:status, status)
     |> assign(:filtered_tree, filtered)}
  end

  defp node_status(%{location: location}, ebird_statuses) do
    case ebird_statuses[location.id] do
      nil -> :no_ebird
      entry -> entry.status
    end
  end

  defp parse_status(nil), do: nil
  defp parse_status("no_ebird"), do: :no_ebird

  defp parse_status(param) do
    Enum.find(@statuses, &(Atom.to_string(&1) == param))
  end

  @impl true
  def handle_event("filter_locations", %{"value" => search_term}, socket) do
    search_term = String.trim(search_term)

    search_results =
      if String.length(search_term) >= 2 do
        Geo.search_common_locations(search_term)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:search_results, search_results)}
  end

  def handle_event("clear_location_filter", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:search_results, [])}
  end

  defp count_nodes(nodes) do
    Enum.reduce(nodes, 0, fn node, acc -> acc + 1 + count_nodes(node.children) end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">
          Common Locations
        </.h1>
        <div class="flex flex-wrap items-center gap-2 mb-1">
          <.action_button
            id="new-location-button"
            navigate={~p"/admin/locations/new"}
            icon="hero-plus"
            variant="secondary"
          >
            New Location
          </.action_button>
          <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg">
            <span id="common-locations-count" class="text-lg font-header font-bold tracking-tight">
              {@locations_count}
            </span>
            <span class="text-forest-100 text-sm font-medium">locations</span>
          </div>
        </div>
      </div>

      <%!-- Search --%>
      <div class="w-full">
        <SearchInput.search_input
          id="location-search"
          value={@search_term}
          placeholder="Search common locations by name, slug, or country code..."
          on_search="filter_locations"
          on_clear="clear_location_filter"
        />
        <div :if={@search_term != ""} class="mt-2 text-sm text-stone-600">
          <%= cond do %>
            <% String.length(@search_term) < 2 -> %>
              Type at least 2 characters to search...
            <% length(@search_results) == 20 -> %>
              Showing first 20 matches — narrow your search to find a specific one
            <% true -> %>
              {length(@search_results)} location(s) found
          <% end %>
        </div>
      </div>

      <%!-- Search results --%>
      <div :if={@search_term != "" and String.length(@search_term) >= 2}>
        <.h2>Search Results</.h2>

        <ul :if={length(@search_results) > 0} class="space-y-2">
          <li
            :for={location <- @search_results}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.location_card
              location={location}
              variant={:flat}
              admin={true}
              ebird_statuses={@ebird_statuses}
            />
          </li>
        </ul>

        <div :if={length(@search_results) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Try a different search term or check your spelling.</p>
        </div>
      </div>

      <%!-- eBird status filter + location tree (hidden when searching) --%>
      <div :if={@search_term == ""} class="space-y-6">
        <ul id="ebird-status-filter" class="flex flex-wrap gap-2">
          <.inline_filter_pill selected={@status == nil} href={~p"/admin/locations"}>
            All ({@countries_count})
          </.inline_filter_pill>
          <.inline_filter_pill
            :for={status <- @statuses}
            selected={@status == status}
            active={Map.get(@status_counts, status, 0) > 0}
            href={~p"/admin/locations?status=#{status}"}
          >
            {ebird_status_label(status)} ({Map.get(@status_counts, status, 0)})
          </.inline_filter_pill>
          <.inline_filter_pill
            selected={@status == :no_ebird}
            active={Map.get(@status_counts, :no_ebird, 0) > 0}
            href={~p"/admin/locations?status=no_ebird"}
          >
            no eBird ({Map.get(@status_counts, :no_ebird, 0)})
          </.inline_filter_pill>
        </ul>

        <ul :if={length(@filtered_tree) > 0} class="space-y-4">
          <li
            :for={node <- @filtered_tree}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.tree_node node={node} admin={true} ebird_statuses={@ebird_statuses} />
          </li>
        </ul>

        <div :if={length(@filtered_tree) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p :if={@location_tree == []} class="text-lg font-medium">No common locations yet</p>
          <p :if={@location_tree == []} class="text-sm">
            Run the ISO 3166 import to seed the scaffold.
          </p>
          <p :if={@location_tree != []} class="text-lg font-medium">
            No countries with this status
          </p>
        </div>
      </div>
    </div>
    """
  end
end
