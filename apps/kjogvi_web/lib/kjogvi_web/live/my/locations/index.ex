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
          {render_location_tree(%{locations: @top_locations, all_locations: @locations, level: 0})}
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
          <details open class="[&_svg]:open:-rotate-90">
            <summary class="flex items-center justify-between p-4 cursor-pointer hover:bg-gray-50 rounded-lg">
              <div class="flex items-center space-x-3">
                <svg
                  class="w-4 h-4 rotate-0 transform text-gray-400 transition-all duration-200"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <polyline points="9 18 15 12 9 6"></polyline>
                </svg>
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
            </summary>

            <div :if={@all_locations[location.id]} class="ml-6 pb-2 pr-4">
              {render_location_tree(%{
                locations: @all_locations[location.id],
                all_locations: @all_locations,
                level: @level + 1
              })}
            </div>
          </details>
        </div>
      <% end %>
    </div>
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
