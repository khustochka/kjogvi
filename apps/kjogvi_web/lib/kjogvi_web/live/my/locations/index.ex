defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    locations = Geo.get_upper_level_locations()

    grouped_locations =
      locations
      |> Enum.group_by(&List.last(&1.ancestry))

    top_locations = grouped_locations[nil]

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, grouped_locations)
      |> assign(:top_locations, top_locations)
      |> assign(:specials, Geo.get_specials())
      |> assign(:search_term, "")
      |> assign(:show_search, false)
      |> assign(:expanded_locations, MapSet.new())
      |> assign(:child_locations, %{})
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {
      :noreply,
      socket
    }
  end

  @impl true
  def handle_event("toggle_search", _params, socket) do
    {:noreply, assign(socket, :show_search, !socket.assigns.show_search)}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    {:noreply, assign(socket, :search_term, search_term)}
  end

  @impl true
  def handle_event("toggle_location", %{"location_id" => location_id_str}, socket) do
    location_id = String.to_integer(location_id_str)
    expanded_locations = socket.assigns.expanded_locations
    child_locations = socket.assigns.child_locations

    {new_expanded, new_child_locations} =
      if MapSet.member?(expanded_locations, location_id) do
        # Collapse - remove from expanded and clear children
        {MapSet.delete(expanded_locations, location_id), Map.delete(child_locations, location_id)}
      else
        # Expand - add to expanded and load children
        children = Geo.get_child_locations(location_id)

        {MapSet.put(expanded_locations, location_id),
         Map.put(child_locations, location_id, children)}
      end

    {:noreply,
     socket
     |> assign(:expanded_locations, new_expanded)
     |> assign(:child_locations, new_child_locations)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header with navigation and search --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center space-x-4">
            <h1 class="text-2xl font-bold text-gray-900">Location Management</h1>
            <div class="flex space-x-2">
              <.link
                patch={~p"/my/locations"}
                class="px-3 py-1.5 text-sm font-medium text-blue-600 bg-blue-50 rounded-md hover:bg-blue-100 border border-blue-200"
              >
                Hierarchy
              </.link>
              <.link
                patch={~p"/my/locations/countries"}
                class="px-3 py-1.5 text-sm font-medium text-gray-600 bg-gray-50 rounded-md hover:bg-gray-100 border border-gray-200"
              >
                Countries
              </.link>
            </div>
          </div>

          <button
            phx-click="toggle_search"
            class="px-4 py-2 text-sm font-medium text-gray-700 bg-white border border-gray-300 rounded-md hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
            <svg class="w-4 h-4 mr-2 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
              >
              </path>
            </svg>
            Search
          </button>
        </div>

        <%!-- Search input --%>
        <div :if={@show_search} class="mb-4">
          <form phx-change="search" class="max-w-md">
            <input
              type="text"
              name="search"
              value={@search_term}
              placeholder="Search locations..."
              class="w-full px-3 py-2 border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            />
          </form>
        </div>

        <%!-- Stats summary --%>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm text-gray-600">
          <div class="flex items-center">
            <svg
              class="w-4 h-4 mr-2 text-blue-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
              >
              </path>
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
              >
              </path>
            </svg>
            <span>{length(@top_locations || [])} top-level locations</span>
          </div>
          <div class="flex items-center">
            <svg
              class="w-4 h-4 mr-2 text-green-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
              >
              </path>
            </svg>
            <span>{length(@specials || [])} special locations</span>
          </div>
          <div class="flex items-center">
            <svg
              class="w-4 h-4 mr-2 text-purple-500"
              fill="none"
              stroke="currentColor"
              viewBox="0 0 24 24"
            >
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              >
              </path>
            </svg>
            <span>Hierarchical structure</span>
          </div>
        </div>
      </div>

      <%!-- Main locations hierarchy --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
        <h2 class="text-lg font-semibold text-gray-900 mb-4">Location Hierarchy</h2>

        <div :if={@top_locations && length(@top_locations) > 0} class="space-y-2">
          {render_location_tree(%{
            locations: @top_locations,
            all_locations: @locations,
            expanded_locations: @expanded_locations,
            child_locations: @child_locations,
            level: 0
          })}
        </div>

        <div
          :if={!@top_locations || length(@top_locations) == 0}
          class="text-center py-8 text-gray-500"
        >
          <svg
            class="w-12 h-12 mx-auto mb-4 text-gray-300"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
            >
            </path>
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
            >
            </path>
          </svg>
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Locations will appear here once they are added to the system.</p>
        </div>
      </div>

      <%!-- Special locations section --%>
      <div
        :if={@specials && length(@specials) > 0}
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <svg
            class="w-5 h-5 mr-2 text-yellow-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M5 3v4M3 5h4M6 17v4m-2-2h4m5-16l2.286 6.857L21 12l-5.714 2.143L13 21l-2.286-6.857L5 12l5.714-2.143L13 3z"
            >
            </path>
          </svg>
          Special Locations
        </h2>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for location <- @specials do %>
            <div class="border border-yellow-200 bg-yellow-50 rounded-lg p-4 hover:shadow-md transition-shadow">
              {location_card(%{location: location, show_type: true})}
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def render_location_tree(assigns) do
    ~H"""
    <div class={"ml-#{@level * 4}"}>
      <%= for location <- @locations do %>
        <div class="border border-gray-100 rounded-lg mb-2 hover:border-gray-200 transition-colors">
          <div class="flex items-center justify-between p-4">
            <div class="flex items-center space-x-3 flex-1">
              <%!-- Expand/collapse button for regions and countries --%>
              <button
                :if={location.location_type in ["country", "region"]}
                phx-click="toggle_location"
                phx-value-location_id={location.id}
                class="flex-shrink-0 p-1 hover:bg-gray-100 rounded"
              >
                <svg
                  class={[
                    "w-4 h-4 transform transition-transform duration-200",
                    if(MapSet.member?(@expanded_locations, location.id),
                      do: "rotate-90",
                      else: "rotate-0"
                    ),
                    "text-gray-400"
                  ]}
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
              </button>

              <%!-- Location icon for non-expandable locations --%>
              <div
                :if={location.location_type not in ["country", "region"]}
                class="w-6 h-6 flex items-center justify-center"
              >
                <div class="w-2 h-2 bg-gray-400 rounded-full"></div>
              </div>

              {location_card(%{location: location, show_type: false})}
            </div>

            <div class="flex items-center space-x-2 text-sm text-gray-500">
              <span
                :if={location.cards_count}
                class="px-2 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-medium"
              >
                {location.cards_count} cards
              </span>
              <span
                :if={location.location_type}
                class="px-2 py-1 bg-gray-100 text-gray-600 rounded-full text-xs"
              >
                {location.location_type}
              </span>
            </div>
          </div>

          <%!-- Children locations --%>
          <div
            :if={MapSet.member?(@expanded_locations, location.id) && @child_locations[location.id]}
            class="ml-6 pb-2 pr-4 border-t border-gray-50"
          >
            <div class="pt-2">
              {render_child_locations(%{
                child_locations: @child_locations[location.id],
                expanded_locations: @expanded_locations,
                child_locations_map: @child_locations,
                level: @level + 1
              })}
            </div>
          </div>

          <%!-- Static children for non-expandable hierarchy --%>
          <div :if={@all_locations[location.id]} class="ml-6 pb-2 pr-4 border-t border-gray-50">
            <div class="pt-2">
              {render_location_tree(%{
                locations: @all_locations[location.id],
                all_locations: @all_locations,
                expanded_locations: @expanded_locations,
                child_locations: @child_locations,
                level: @level + 1
              })}
            </div>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def render_child_locations(assigns) do
    ~H"""
    <%= for {parent_id, children} <- @child_locations do %>
      <div class="space-y-2">
        <%= for child <- children do %>
          <div class="border border-gray-50 rounded-lg p-3 hover:border-gray-100 transition-colors">
            <div class="flex items-center justify-between">
              <div class="flex items-center space-x-3 flex-1">
                <%!-- Expand/collapse button for regions --%>
                <button
                  :if={child.location_type == "region"}
                  phx-click="toggle_location"
                  phx-value-location_id={child.id}
                  class="flex-shrink-0 p-1 hover:bg-gray-100 rounded"
                >
                  <svg
                    class={[
                      "w-3 h-3 transform transition-transform duration-200",
                      if(MapSet.member?(@expanded_locations, child.id),
                        do: "rotate-90",
                        else: "rotate-0"
                      ),
                      "text-gray-400"
                    ]}
                    fill="none"
                    stroke="currentColor"
                    viewBox="0 0 24 24"
                  >
                    <polyline points="9 18 15 12 9 6"></polyline>
                  </svg>
                </button>

                <%!-- Location icon for non-expandable locations --%>
                <div
                  :if={child.location_type != "region"}
                  class="w-5 h-5 flex items-center justify-center"
                >
                  <div class="w-1.5 h-1.5 bg-gray-400 rounded-full"></div>
                </div>

                {location_card(%{location: child, show_type: false})}
              </div>

              <div class="flex items-center space-x-2 text-xs text-gray-500">
                <span
                  :if={child.cards_count}
                  class="px-2 py-1 bg-blue-100 text-blue-700 rounded-full font-medium"
                >
                  {child.cards_count}
                </span>
                <span
                  :if={child.location_type}
                  class="px-2 py-1 bg-gray-100 text-gray-600 rounded-full"
                >
                  {child.location_type}
                </span>
              </div>
            </div>

            <%!-- Nested children --%>
            <div
              :if={MapSet.member?(@expanded_locations, child.id) && @child_locations_map[child.id]}
              class="ml-4 mt-2 pt-2 border-t border-gray-50"
            >
              {render_child_locations(%{
                child_locations: @child_locations_map[child.id],
                expanded_locations: @expanded_locations,
                child_locations_map: @child_locations_map,
                level: @level + 1
              })}
            </div>
          </div>
        <% end %>
      </div>
    <% end %>
    """
  end

  def location_card(assigns) do
    ~H"""
    <div class="flex items-center space-x-3">
      <div class="flex-shrink-0">
        <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
          <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
            >
            </path>
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M15 11a3 3 0 11-6 0 3 3 0 016 0z"
            >
            </path>
          </svg>
        </div>
      </div>

      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium text-gray-900 truncate">{@location.name_en}</p>
        <div class="flex items-center space-x-2 text-xs text-gray-500">
          <span class="truncate">{@location.slug}</span>
          <span :if={@location.iso_code && @location.iso_code != ""} class="font-mono">
            {String.upcase(@location.iso_code)}
          </span>
        </div>
      </div>
    </div>
    """
  end
end
