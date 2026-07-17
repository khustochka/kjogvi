defmodule KjogviWeb.Live.Admin.Locations.Index do
  @moduledoc """
  Admin index of the common locations dataset: the shared scaffold as a
  lazily loaded collapsible tree with text search. Only the countries load up
  front; a branch's children are fetched on first expand. Unlike
  `Live.My.Locations.Index` it shows every common location — including
  countries nothing hangs under yet — and no personal locations.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Util.Number
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Common Locations")
     |> assign(:location_tree, Geo.common_location_roots())
     |> assign(:locations_count, Geo.common_locations_count())
     |> assign(:search_term, "")
     |> assign(:search_results, [])}
  end

  @impl true
  def handle_event("expand", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    children = Geo.common_location_children(id)

    {:noreply, assign(socket, :location_tree, graft(socket.assigns.location_tree, id, children))}
  end

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

  # Sets the loaded children on node `id`, wherever it sits among the loaded
  # branches.
  defp graft(nodes, id, children) do
    Enum.map(nodes, fn
      %{location: %{id: ^id}} = node -> %{node | children: children}
      %{children: nil} = node -> node
      node -> %{node | children: graft(node.children, id, children)}
    end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.section_nav>
        <:item href={~p"/admin/locations"} current>Common</:item>
        <:item href={~p"/admin/ebird/locations"}>eBird</:item>
        <:item href={~p"/admin/imports/locations"}>Imports</:item>
      </.section_nav>

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

      <%!-- Location tree (hidden when searching) --%>
      <div :if={@search_term == ""} class="space-y-6">
        <ul :if={length(@location_tree) > 0} class="space-y-4">
          <li
            :for={node <- @location_tree}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.tree_node node={node} admin={true} />
          </li>
        </ul>

        <div :if={length(@location_tree) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No common locations yet</p>
          <p class="text-sm">
            Run the ISO 3166 import to seed the scaffold.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
