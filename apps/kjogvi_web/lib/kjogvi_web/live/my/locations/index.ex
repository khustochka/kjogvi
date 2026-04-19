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
  def handle_event("delete", %{"id" => id_str}, socket) do
    location = Kjogvi.Repo.get!(Kjogvi.Geo.Location, String.to_integer(id_str))

    case Geo.delete_location(location) do
      {:ok, _} ->
        grouped_locations = Geo.all_locations_by_parent()
        top_locations = grouped_locations[nil] || []

        {:noreply,
         socket
         |> put_flash(:info, "Location deleted")
         |> assign(:grouped_locations, grouped_locations)
         |> assign(:name_cache, build_name_cache(grouped_locations))
         |> assign(:top_locations, top_locations)
         |> assign(:total_locations, count_locations(grouped_locations))}

      {:error, :has_children} ->
        {:noreply, put_flash(socket, :error, "Cannot delete: location has sub-locations")}

      {:error, :has_cards} ->
        {:noreply, put_flash(socket, :error, "Cannot delete: location has cards")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Could not delete location")}
    end
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
        <div class="flex flex-wrap items-stretch gap-2 mb-1">
          <.action_button navigate={~p"/my/locations/new"} icon="hero-plus">
            Add Location
          </.action_button>
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

        <div :if={length(@search_results) > 0} class="space-y-2">
          <%= for location <- @search_results do %>
            <div class="border border-stone-200 rounded-lg p-3">
              <div class="flex items-center justify-between gap-2">
                <div class="flex-1 min-w-0">
                  <.location_row location={location} />
                </div>

                <.lifelist_link slug={location.slug} />
                <.row_actions
                  location={location}
                  can_delete={Geo.can_delete_location?(location)}
                />
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

        <.lifelist_link slug={@location.slug} />
        <.row_actions
          location={@location}
          can_delete={!has_children?(assigns) and (Map.get(@location, :cards_count) || 0) == 0}
        />
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
  attr :can_delete, :boolean, required: true

  def row_actions(assigns) do
    ~H"""
    <div class="shrink-0 flex items-center gap-1">
      <.link
        href={~p"/my/locations/#{@location.slug}/edit"}
        class="p-1.5 text-stone-500 hover:text-stone-800 hover:bg-stone-100 rounded"
        title="Edit"
      >
        <.icon name="hero-pencil-square" class="w-4 h-4" />
      </.link>
      <button
        :if={@can_delete}
        type="button"
        phx-click="delete"
        phx-value-id={@location.id}
        data-confirm={"Delete location \"#{@location.name_en}\"? This cannot be undone."}
        class="p-1.5 text-rose-600 hover:text-rose-800 hover:bg-rose-50 rounded"
        title="Delete"
      >
        <.icon name="hero-trash" class="w-4 h-4" />
      </button>
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
