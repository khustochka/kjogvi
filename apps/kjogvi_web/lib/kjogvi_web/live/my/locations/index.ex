defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    grouped_locations = Geo.all_locations_by_parent()

    # Start with only top-level locations (no parents)
    top_locations = grouped_locations[nil] || []

    # Auto-expand top-level locations to show countries by default
    expanded_locations = top_locations |> Enum.map(& &1.id) |> MapSet.new()

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:grouped_locations, grouped_locations)
      |> assign(:name_cache, build_name_cache(grouped_locations))
      |> assign(:top_locations, top_locations)
      |> assign(:total_locations, count_locations(grouped_locations))
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:specials, Geo.get_specials())
      |> assign(:expanded_locations, expanded_locations)
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

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:search_results, search_results)}
  end

  @impl true
  def handle_event("toggle_location", %{"location_id" => location_id_str}, socket) do
    location_id = String.to_integer(location_id_str)
    expanded = socket.assigns.expanded_locations

    new_expanded =
      if MapSet.member?(expanded, location_id),
        do: MapSet.delete(expanded, location_id),
        else: MapSet.put(expanded, location_id)

    {:noreply, assign(socket, :expanded_locations, new_expanded)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Header + stats --%>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <.h1 class="mb-0!">
          Locations
        </.h1>
        <div class="flex flex-wrap gap-2 mb-1">
          <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg">
            <span class="text-lg font-header font-bold tracking-tight">
              {@total_locations}
            </span>
            <span class="text-forest-100 text-sm font-medium">total</span>
          </div>
          <div class="inline-flex items-baseline gap-2 bg-stone-600 text-white px-3 py-2 rounded-lg">
            <span class="text-lg font-header font-bold tracking-tight">
              {length(@top_locations)}
            </span>
            <span class="text-stone-200 text-sm font-medium">top-level</span>
          </div>
          <div
            :if={length(@specials) > 0}
            class="inline-flex items-baseline gap-2 bg-stone-500 text-white px-3 py-2 rounded-lg"
          >
            <span class="text-lg font-header font-bold tracking-tight">
              {length(@specials)}
            </span>
            <span class="text-stone-200 text-sm font-medium">special</span>
          </div>
        </div>
      </div>

      <%!-- Search --%>
      <div class="w-full">
        <form phx-change="search" class="w-full">
          <input
            id="location-search"
            type="search"
            name="search"
            value={@search_term}
            placeholder="Search locations by name, slug, or country code..."
            class="w-full px-3 py-2 text-stone-900 bg-white border border-stone-300 rounded-md focus:outline-none focus:ring-2 focus:ring-forest-500 focus:border-forest-500"
            phx-debounce="300"
          />
        </form>
        <div :if={@search_term != ""} class="mt-2 text-sm text-stone-600">
          <%= if String.length(@search_term) < 2 do %>
            Type at least 2 characters to search...
          <% else %>
            {length(@search_results)} location(s) found
            <%= if length(@search_results) == 20 do %>
              (showing first 20 results)
            <% end %>
          <% end %>
        </div>
      </div>

      <%!-- Search results --%>
      <div :if={@search_term != "" and String.length(@search_term) >= 2}>
        <.h2>Search Results</.h2>

        <div :if={length(@search_results) > 0} class="space-y-2">
          <%= for location <- @search_results do %>
            <div class="border border-stone-200 rounded-lg p-3">
              <div class="flex items-center justify-between gap-2">
                <div class="flex-1 min-w-0">
                  <.location_row location={location} />
                </div>

                <.link
                  href={~p"/my/lifelist/#{location.slug}"}
                  class="shrink-0 ml-4 px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-600 bg-forest-50 hover:bg-forest-100 rounded no-underline"
                >
                  Lifelist
                </.link>
              </div>

              <div :if={length(location.ancestry) > 0} class="mt-1 text-xs text-stone-400">
                <.location_breadcrumb ancestry={location.ancestry} name_cache={@name_cache} />
              </div>
            </div>
          <% end %>
        </div>

        <div :if={length(@search_results) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Try a different search term or check your spelling.</p>
        </div>
      </div>

      <%!-- Main locations hierarchy (hidden when searching) --%>
      <div :if={@search_term == ""}>
        <div :if={@top_locations && length(@top_locations) > 0} class="border-r border-stone-200">
          <%= for location <- @top_locations do %>
            <.render_location
              grouped_locations={@grouped_locations}
              children={Map.get(@grouped_locations, location.id, [])}
              location={location}
              expanded_locations={@expanded_locations}
              level={0}
            />
          <% end %>
        </div>

        <div
          :if={!@top_locations || length(@top_locations) == 0}
          class="text-center py-8 text-stone-500"
        >
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Locations will appear here once they are added to the system.</p>
        </div>
      </div>

      <%!-- Special locations section --%>
      <div :if={@specials && length(@specials) > 0}>
        <.h2>Special Locations</.h2>

        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          <%= for location <- @specials do %>
            <div class="border border-stone-200 bg-stone-50 rounded-lg p-4">
              <.location_row location={location} />
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp has_children?(assigns), do: assigns.children != []

  def render_location(assigns) do
    ~H"""
    <div class="mb-2 border-t border-b border-l border-stone-200 rounded-l-lg">
      <div class="flex items-center justify-between gap-2 p-3">
        <div class="flex items-center space-x-2 flex-1 min-w-0">
          <%= if has_children?(assigns) do %>
            <button
              phx-click="toggle_location"
              phx-value-location_id={@location.id}
              class="shrink-0 p-1 hover:bg-stone-50 rounded transition-colors"
            >
              <.icon
                name="hero-chevron-right"
                class={"w-4 h-4 text-stone-400 hover:text-stone-600 transition-transform duration-200 #{if MapSet.member?(@expanded_locations, @location.id), do: "rotate-90", else: ""}"}
              />
            </button>
          <% else %>
            <div class="shrink-0 w-6"></div>
          <% end %>

          <div class="flex-1 min-w-0">
            <.location_row location={@location} />
          </div>
        </div>

        <.link
          href={~p"/my/lifelist/#{@location.slug}"}
          class="shrink-0 ml-4 px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-600 bg-forest-50 hover:bg-forest-100 rounded no-underline"
        >
          Lifelist
        </.link>
      </div>

      <%= if has_children?(assigns) and MapSet.member?(@expanded_locations, @location.id) do %>
        <div class="pl-3 pb-3">
          <%= for child <- Map.get(@grouped_locations, @location.id, []) do %>
            <.render_location
              location={child}
              grouped_locations={@grouped_locations}
              children={Map.get(@grouped_locations, child.id, [])}
              expanded_locations={@expanded_locations}
              level={@level + 1}
            />
          <% end %>
        </div>
      <% end %>
    </div>
    """
  end

  attr :location, :map, required: true

  def location_row(assigns) do
    ~H"""
    <div class="min-w-0">
      <div class="flex flex-col sm:flex-row sm:items-center sm:space-x-2 space-y-0.5 sm:space-y-0">
        <div class="flex items-center space-x-2 min-w-0">
          <span class="text-sm font-medium text-stone-800 truncate">
            <.link
              href={~p"/my/locations/#{@location.slug}"}
              class="text-stone-800 hover:underline no-underline"
            >
              {@location.name_en}
            </.link>
          </span>
          <%= if @location.is_private do %>
            <span title="Private">
              <.icon name="hero-lock-closed" class="w-4 h-4 text-stone-700 shrink-0" />
            </span>
          <% end %>
          <span
            :if={@location.iso_code && @location.iso_code != ""}
            class="text-stone-500 font-mono text-sm shrink-0"
          >
            {String.upcase(@location.iso_code)}
          </span>
        </div>
      </div>
      <div class="flex flex-wrap items-center gap-x-2 gap-y-1 mt-0.5">
        <span class="text-xs text-stone-500 truncate">{@location.slug}</span>
        <span
          :if={@location.location_type}
          class={[
            "inline-block px-2 py-0.5 text-xs font-medium rounded-full shrink-0",
            type_badge_classes(@location.location_type)
          ]}
        >
          {@location.location_type}
        </span>
      </div>
    </div>
    """
  end

  def location_breadcrumb(assigns) do
    ~H"""
    <span class="text-stone-400">
      <%= for {ancestor_id, index} <- Enum.with_index(@ancestry) do %>
        <%= if index > 0 do %>
          >
        <% end %>
        {Map.get(@name_cache, ancestor_id, "Unknown")}
      <% end %>
    </span>
    """
  end

  defp type_badge_classes(type) do
    case type do
      "continent" -> "bg-forest-100 text-forest-700"
      "country" -> "bg-sky-100 text-sky-700"
      "region" -> "bg-amber-100 text-amber-700"
      "city" -> "bg-violet-100 text-violet-700"
      "raion" -> "bg-teal-100 text-teal-700"
      "special" -> "bg-rose-100 text-rose-700"
      _other -> "bg-stone-100 text-stone-600"
    end
  end

  defp build_name_cache(grouped_locations) do
    grouped_locations
    |> Enum.flat_map(fn {_parent_id, locations} -> locations end)
    |> Map.new(fn loc -> {loc.id, loc.name_en} end)
  end

  defp count_locations(grouped_locations) do
    Enum.reduce(grouped_locations, 0, fn {_parent_id, locations}, acc ->
      acc + length(locations)
    end)
  end
end
