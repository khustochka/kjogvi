defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts.User
  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign_locations(scope)
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:delete_error, nil)
      |> assign(:specials, Geo.get_specials(scope))
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_locations", %{"value" => search_term}, socket) do
    search_term = String.trim(search_term)

    search_results =
      if String.length(search_term) >= 2 do
        Geo.search_locations(socket.assigns.current_scope, search_term)
      else
        []
      end

    {:noreply,
     socket
     |> assign(:search_term, search_term)
     |> assign(:search_results, search_results)
     |> assign(:delete_error, nil)}
  end

  def handle_event("clear_location_filter", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:search_results, [])
     |> assign(:delete_error, nil)}
  end

  @impl true
  def handle_event("delete", %{"id" => id_str}, socket) do
    location = Kjogvi.Repo.get!(Kjogvi.Geo.Location, String.to_integer(id_str))

    case Geo.delete_location(socket.assigns.current_scope, location) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location deleted")
         |> assign(:delete_error, nil)
         |> assign_locations(socket.assigns.current_scope)}

      {:error, :has_children} ->
        {:noreply, row_delete_error(socket, location.id, "Has sub-locations — can't delete")}

      {:error, :has_cards} ->
        {:noreply, row_delete_error(socket, location.id, "Has cards — can't delete")}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "You can only delete your own locations")}

      {:error, _} ->
        {:noreply, row_delete_error(socket, location.id, "Could not delete")}
    end
  end

  # Records a delete failure against a single row; the row renders it inline.
  defp row_delete_error(socket, id, message) do
    assign(socket, :delete_error, {id, message})
  end

  defp assign_locations(socket, scope) do
    locations = Geo.list_locations(scope)

    socket
    |> assign(:locations, locations)
    |> assign(:total_locations, length(locations))
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
        <SearchInput.search_input
          id="location-search"
          value={@search_term}
          placeholder="Search locations by name, slug, or country code..."
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
            class="border border-stone-200 rounded-lg p-3"
          >
            <.location_entry
              location={location}
              current_user={@current_scope.current_user}
              delete_error={delete_error_for(@delete_error, location.id)}
            />
          </li>
        </ul>

        <div :if={length(@search_results) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-magnifying-glass" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Try a different search term or check your spelling.</p>
        </div>
      </div>

      <%!-- Full location list (hidden when searching) --%>
      <div :if={@search_term == ""}>
        <ul
          :if={length(@locations) > 0}
          class="border border-stone-200 rounded-lg divide-y divide-stone-100"
        >
          <li
            :for={location <- @locations}
            class="p-3"
          >
            <.location_entry
              location={location}
              current_user={@current_scope.current_user}
              delete_error={delete_error_for(@delete_error, location.id)}
            />
          </li>
        </ul>

        <div :if={length(@locations) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Locations will appear here once they are added to the system.</p>
        </div>
      </div>

      <%!-- Special locations section --%>
      <div :if={@specials && length(@specials) > 0}>
        <.h2>Special Locations</.h2>

        <ul class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3">
          <li
            :for={location <- @specials}
            class="border border-stone-200 bg-stone-50 rounded-lg p-4"
          >
            <.location_row location={location} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :location, :map, required: true
  attr :current_user, :any, default: nil
  attr :delete_error, :string, default: nil

  defp location_entry(assigns) do
    ~H"""
    <div class="flex items-center justify-between gap-2">
      <div class="flex-1 min-w-0">
        <.location_row location={@location} />
        <p
          :if={Location.long_name(:private, @location) != @location.name_en}
          class="mt-1 text-xs text-stone-400"
        >
          {Location.long_name(:private, @location)}
        </p>
      </div>

      <div class="flex flex-col items-end gap-1">
        <div class="flex items-center gap-2">
          <.row_actions
            location={@location}
            can_modify={User.owns?(@current_user, @location)}
          />
          <.lifelist_link slug={@location.slug} />
        </div>
        <p
          :if={@delete_error}
          id={"location-delete-error-#{@location.id}"}
          class="text-right text-xs text-rose-600"
        >
          {@delete_error}
        </p>
      </div>
    </div>
    """
  end

  # The delete-failure message for `id`, or `nil` when the failure (if any) is
  # for a different row.
  defp delete_error_for({id, message}, id), do: message
  defp delete_error_for(_, _), do: nil

  attr :location, :map, required: true
  attr :can_modify, :boolean, default: false

  # The delete button is shown for every owned location; deletability (no
  # children, no cards) is enforced server-side by `Geo.delete_location/2`,
  # which flashes an error if the location is still in use. This keeps the list
  # free of a per-row deletability query.
  defp row_actions(assigns) do
    ~H"""
    <div class="shrink-0 flex items-center gap-1">
      <.link
        :if={@can_modify}
        href={~p"/my/locations/#{@location.slug}/edit"}
        class="p-1.5 text-stone-500 hover:text-stone-800 hover:bg-stone-100 rounded"
        title="Edit"
      >
        <.icon name="hero-pencil-square" class="w-4 h-4" />
      </.link>
      <button
        :if={@can_modify}
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
end
