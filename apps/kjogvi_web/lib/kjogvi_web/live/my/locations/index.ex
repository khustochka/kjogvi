defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    {all_locations, grouped_locations} = Geo.get_all_locations_grouped()

    # Start with only top-level locations (no parents)
    top_locations = grouped_locations[nil] || []

    # Auto-expand top-level locations to show countries by default
    continent_ids = top_locations |> Enum.map(& &1.id) |> MapSet.new()

    # Load children for all continents
    open_locations =
      top_locations
      |> Enum.reduce(%{}, fn continent, acc ->
        Map.put(acc, continent.id, grouped_locations[continent.id] || [])
      end)

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:grouped_locations, grouped_locations)
      |> assign(:all_locations, all_locations |> Map.new(fn loc -> {loc.id, loc} end))
      |> assign(:top_locations, top_locations)
      |> assign(:total_locations, length(all_locations))
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:specials, Geo.get_specials())
      |> assign(:expanded_locations, continent_ids)
      |> assign(:open_locations, open_locations)
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"search" => search_term}, socket) do
    search_term = String.trim(search_term)

    search_results =
      if String.length(search_term) >= 2 do
        Geo.search_locations(search_term)
      else
        []
      end

    # Preload ancestor names for search results that have ancestry
    ancestor_cache =
      if search_results != [] do
        search_results
        |> Enum.flat_map(& &1.ancestry)
        |> Enum.uniq()
        |> Enum.map(&{&1, socket.assigns.all_locations[&1].name_en})
        |> Map.new()
      else
        %{}
      end

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:search_results, search_results)
     |> assign(:ancestor_cache, ancestor_cache)}
  end

  @impl true
  def handle_event("toggle_location", %{"location_id" => location_id_str}, socket) do
    location_id = String.to_integer(location_id_str)

    %{
      expanded_locations: expanded_locations,
      open_locations: open_locations,
      grouped_locations: grouped_locations
    } = socket.assigns

    {new_expanded, new_open_locations} =
      if MapSet.member?(expanded_locations, location_id) do
        # Collapse - remove from expanded and clear children
        {MapSet.delete(expanded_locations, location_id), Map.delete(open_locations, location_id)}
      else
        {MapSet.put(expanded_locations, location_id),
         Map.put(open_locations, location_id, grouped_locations[location_id])}
      end

    {:noreply,
     socket
     |> assign(:expanded_locations, new_expanded)
     |> assign(:open_locations, new_open_locations)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <.h1>
        Locations
      </.h1>

      <%!-- Stats summary --%>
      <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6">
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-4 text-sm text-gray-600">
          <div class="flex items-center">
            <svg
              class="w-4 h-4 mr-2 text-blue-500 shrink-0"
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
            </svg>
            <span>{length(@top_locations || [])} top-level locations</span>
          </div>
          <div class="flex items-center">
            <svg
              class="w-4 h-4 mr-2 text-green-500 shrink-0"
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
              class="w-4 h-4 mr-2 text-purple-500 shrink-0"
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
            <span>
              {@total_locations} total locations
            </span>
          </div>
        </div>
      </div>

      <div class="w-full">
        <%!-- Search results count --%>
        <div :if={@search_term != ""} class="mt-2 text-sm text-gray-600">
          <%= if String.length(@search_term) < 2 do %>
            Type at least 2 characters to search...
          <% else %>
            {length(@search_results)} location(s) found
            <%= if length(@search_results) == 20 do %>
              (showing first 20 results)
            <% end %>
          <% end %>
        </div>

        <form phx-change="search" class="w-full">
          <input
            id="location-search"
            type="search"
            name="search"
            value={@search_term}
            placeholder="Search locations by name, slug, or country code..."
            class="w-full px-3 py-2 text-gray-900 bg-white border border-gray-300 rounded-md shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500"
            phx-debounce="300"
          />
        </form>
      </div>

      <%!-- Search results --%>
      <div
        :if={@search_term != "" and String.length(@search_term) >= 2}
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <svg
            class="w-5 h-5 mr-2 text-blue-500 shrink-0"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            >
            </path>
          </svg>
          Search Results
        </h2>

        <div :if={length(@search_results) > 0} class="space-y-2">
          <%= for location <- @search_results do %>
            <div class="border border-gray-100 rounded-lg p-4 hover:border-gray-200 transition-colors">
              <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
                <div class="flex-1 min-w-0">
                  <.location_card location={location} show_type={false} />
                </div>

                <div class="flex items-center space-x-4 text-sm text-gray-500 shrink-0">
                  <.link
                    href={~p"/my/lifelist/#{location.slug}"}
                    class="text-blue-600 hover:text-blue-700 text-sm lg:text-base hover:underline transition-colors"
                  >
                    Lifelist
                  </.link>
                </div>
              </div>

              <%!-- Show location path/breadcrumb --%>
              <div :if={length(location.ancestry) > 0} class="mt-2 text-xs text-gray-500">
                <span class="font-medium">Path:</span>
                <.location_breadcrumb ancestry={location.ancestry} ancestor_cache={@ancestor_cache} />
              </div>
            </div>
          <% end %>
        </div>

        <div :if={length(@search_results) == 0} class="text-center py-8 text-gray-500">
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
              d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
            >
            </path>
          </svg>
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Try a different search term or check your spelling.</p>
        </div>
      </div>

      <%!-- Main locations hierarchy (hidden when searching) --%>
      <div
        :if={@search_term == ""}
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6"
      >
        <div :if={@top_locations && length(@top_locations) > 0} class="space-y-2">
          <%= for location <- @top_locations do %>
            <.render_location
              grouped_locations={@grouped_locations}
              children={Map.get(@grouped_locations, location.id, [])}
              location={location}
              expanded_locations={@expanded_locations}
              open_locations={@open_locations}
              level={0}
            />
          <% end %>
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
          </svg>
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Locations will appear here once they are added to the system.</p>
        </div>
      </div>

      <%!-- Special locations section --%>
      <div
        :if={@specials && length(@specials) > 0}
        class="bg-white rounded-lg shadow-sm border border-gray-200 p-4 sm:p-6"
      >
        <h2 class="text-lg font-semibold text-gray-900 mb-4 flex items-center">
          <svg
            class="w-5 h-5 mr-2 text-yellow-500 shrink-0"
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

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
          <%= for location <- @specials do %>
            <div class="border border-yellow-200 bg-yellow-50 rounded-lg p-4 hover:shadow-md transition-shadow">
              <.location_card location={location} show_type={true} />
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  def render_location(assigns) do
    ~H"""
    <div class="border border-gray-100 rounded-lg mb-2 hover:border-gray-200 transition-colors">
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between p-4 gap-4">
        <div class="flex items-center space-x-3 flex-1 min-w-0">
          <%!-- Expand/collapse button only for locations with children --%>
          <%= if Enum.any?(@children) do %>
            <button
              phx-click="toggle_location"
              phx-value-location_id={@location.id}
              class="shrink-0 p-1 hover:bg-gray-50 rounded transition-colors"
            >
              <svg
                class={[
                  "w-4 h-4 text-gray-500 transition-transform duration-200",
                  if(MapSet.member?(@expanded_locations, @location.id), do: "rotate-90", else: "")
                ]}
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7">
                </path>
              </svg>
            </button>
          <% else %>
            <div class="shrink-0 p-1 w-6 h-6"></div>
          <% end %>

          <div class="flex-1 min-w-0">
            <.location_card location={@location} show_type={false} />
          </div>
        </div>

        <div class="flex items-center space-x-4 text-sm text-gray-500 shrink-0 sm:ml-4">
          <.link
            href={~p"/my/lifelist/#{@location.slug}"}
            class="text-blue-600 hover:text-blue-700 text-sm lg:text-base hover:underline transition-colors"
          >
            Lifelist
          </.link>
        </div>
      </div>

      <%!-- Children locations --%>
      <%= if MapSet.member?(@expanded_locations, @location.id) && @open_locations[@location.id] do %>
        <div class="ml-4 sm:ml-6 pb-2 pr-4 border-t border-gray-50">
          <div class="pt-2">
            <%= for child <- @open_locations[@location.id] do %>
              <.render_location
                location={child}
                grouped_locations={@grouped_locations}
                children={Map.get(@grouped_locations, child.id, [])}
                expanded_locations={@expanded_locations}
                open_locations={@open_locations}
                level={@level + 1}
              />
            <% end %>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  def location_card(assigns) do
    ~H"""
    <div class="flex items-center space-x-3 min-w-0">
      <div class="shrink-0">
        <div class="w-8 h-8 bg-blue-100 rounded-full flex items-center justify-center">
          <svg class="w-4 h-4 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="2"
              d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z"
            >
            </path>
          </svg>
        </div>
      </div>

      <div class="flex-1 min-w-0">
        <div class="flex flex-col sm:flex-row sm:items-center sm:space-x-2 space-y-1 sm:space-y-0">
          <div class="flex items-center space-x-2 min-w-0">
            <p class="text-sm font-medium text-gray-900 truncate">{@location.name_en}</p>
            <%= if @location.is_private do %>
              <span title="Private">
                <svg
                  class="w-4 h-4 text-gray-400 shrink-0"
                  fill="none"
                  stroke="currentColor"
                  viewBox="0 0 24 24"
                >
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z"
                  >
                  </path>
                </svg>
              </span>
            <% end %>
            <span
              :if={@location.iso_code && @location.iso_code != ""}
              class="text-gray-600 font-mono text-sm shrink-0"
            >
              {String.upcase(@location.iso_code)}
            </span>
          </div>
        </div>
        <div class="flex flex-wrap items-center gap-x-2 gap-y-1 mt-1">
          <p class="text-xs text-gray-500 truncate">{@location.slug}</p>
          <span
            :if={@location.location_type}
            class="inline-block px-2 py-1 text-xs font-medium bg-gray-100 text-gray-700 rounded-full shrink-0"
          >
            {@location.location_type}
          </span>
        </div>
      </div>
    </div>
    """
  end

  def location_breadcrumb(assigns) do
    ~H"""
    <span class="text-gray-400">
      <%= for {ancestor_id, index} <- Enum.with_index(@ancestry) do %>
        <%= if index > 0 do %>
          >
        <% end %>
        {Map.get(@ancestor_cache, ancestor_id, "Unknown")}
      <% end %>
    </span>
    """
  end
end
