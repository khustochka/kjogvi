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
  alias Kjogvi.Util.Number
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @impl true
  def mount(_params, _session, socket) do
    tree = Geo.common_location_tree()

    countries = for %{location: %{location_type: :country} = location} <- tree, do: location

    {:ok,
     socket
     |> assign(:page_title, "Common Locations")
     |> assign(:location_tree, tree)
     |> assign(:locations_count, count_nodes(tree))
     |> assign(:countries_count, length(countries))
     |> assign(:search_term, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    filtered = socket.assigns.location_tree

    {:noreply,
     socket
     |> assign(:filtered_tree, filtered)}
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
        <div class="flex flex-wrap items-stretch gap-2 mb-1">
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
              {Number.delimit(@locations_count)}
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
        <ul :if={length(@filtered_tree) > 0} class="space-y-4">
          <li
            :for={node <- @filtered_tree}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.tree_node node={node} admin={true} />
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
