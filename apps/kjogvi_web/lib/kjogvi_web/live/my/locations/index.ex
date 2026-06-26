defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Accounts.User
  alias Kjogvi.Geo
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope
    specials = Geo.get_specials(scope)

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign_locations(scope)
      |> assign(:search_term, "")
      |> assign(:search_results, [])
      |> assign(:delete_error, nil)
      |> assign(:specials, specials)
      |> assign(:own_specials_count, Enum.count(specials, &User.owns?(scope.current_user, &1)))
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

      {:error, :has_checklists} ->
        {:noreply, row_delete_error(socket, location.id, "Has checklists — can't delete")}

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
    own_count =
      Geo.list_locations(scope)
      |> Enum.count(&User.owns?(scope.current_user, &1))

    socket
    |> assign(:location_tree, Geo.location_tree(scope))
    |> assign(:own_locations_count, own_count)
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
            <span id="own-locations-count" class="text-lg font-header font-bold tracking-tight">
              {@own_locations_count}
            </span>
            <span class="text-forest-100 text-sm font-medium">mine</span>
          </div>
          <a
            :if={@own_specials_count > 0}
            href="#special-locations"
            class="inline-flex items-baseline gap-2 bg-rose-600 hover:bg-rose-700 text-white px-3 py-2 rounded-lg no-underline"
          >
            <span id="own-specials-count" class="text-lg font-header font-bold tracking-tight">
              {@own_specials_count}
            </span>
            <span class="text-rose-100 text-sm font-medium">special</span>
          </a>
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
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.location_card
              location={location}
              variant={:flat}
              current_user={@current_scope.current_user}
              delete_error={@delete_error}
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
      <div :if={@search_term == ""}>
        <ul :if={length(@location_tree) > 0} class="space-y-4">
          <li
            :for={node <- @location_tree}
            class="border border-stone-200 rounded-lg overflow-hidden"
          >
            <.tree_node
              node={node}
              current_user={@current_scope.current_user}
              delete_error={@delete_error}
            />
          </li>
        </ul>

        <div :if={length(@location_tree) == 0} class="text-center py-8 text-stone-500">
          <.icon name="hero-map-pin" class="w-12 h-12 mx-auto mb-4 text-stone-300" />
          <p class="text-lg font-medium">No locations found</p>
          <p class="text-sm">Locations will appear here once you add them.</p>
        </div>
      </div>

      <%!-- Special locations section (hidden when searching) --%>
      <div
        :if={@search_term == "" && @specials && length(@specials) > 0}
        id="special-locations"
      >
        <.h2>Special Locations</.h2>

        <ul class="space-y-2">
          <li :for={location <- @specials} class="rounded-lg overflow-hidden">
            <.location_card location={location} variant={:flat} />
          </li>
        </ul>
      </div>
    </div>
    """
  end

  attr :node, :map, required: true
  attr :current_user, :any, default: nil
  attr :delete_error, :any, default: nil

  # One tree node, rendered recursively. The location body is delegated to
  # `location_card` (the `:tree` variant adds the type-keyed tint without its own
  # horizontal padding, which the branch wrapper here supplies). A node with
  # children gets a chevron that toggles them. Only countries start expanded, so
  # the common scaffold — countries and their subdivisions — is what shows
  # initially; everything below a subdivision stays collapsed until expanded.
  defp tree_node(assigns) do
    location = assigns.node.location
    body_id = "tree-body-#{location.id}"
    has_children = assigns.node.children != []
    expanded = location.location_type == :country

    assigns =
      assign(assigns,
        body_id: body_id,
        has_children: has_children,
        expanded: expanded
      )

    ~H"""
    <div class={["flex items-center gap-1.5 px-3", tree_node_pad(@node.location)]}>
      <.tree_toggle
        :if={@has_children}
        target={@body_id}
        label={"Toggle #{@node.location.name_en}"}
        expanded={@expanded}
      />
      <span :if={!@has_children} class="w-5 shrink-0" aria-hidden="true"></span>
      <div class="flex-1 min-w-0">
        <.location_card
          location={@node.location}
          variant={:tree}
          current_user={@current_user}
          delete_error={@delete_error}
        />
      </div>
    </div>

    <ul
      :if={@has_children}
      id={@body_id}
      class={["border-l border-stone-200 ml-3", !@expanded && "hidden"]}
    >
      <li :for={child <- @node.children} class="border-t border-stone-200">
        <.tree_node
          node={child}
          current_user={@current_user}
          delete_error={@delete_error}
        />
      </li>
    </ul>
    """
  end

  # The chevron-row tint matches the location checklist it wraps, so the toggle sits on
  # the same background as the row (the checklist carries no horizontal padding here).
  defp tree_node_pad(%{location_type: :country}), do: "bg-sky-50"
  defp tree_node_pad(%{location_type: :subdivision1}), do: "bg-amber-50"
  defp tree_node_pad(%{user_id: nil}), do: "bg-stone-50"
  defp tree_node_pad(_personal), do: "bg-white"

  # Chevron toggle for a tree branch. `target` is the id (no `#`) of the body to
  # show/hide. `expanded` sets the initial state (chevron down + body shown).
  attr :target, :string, required: true
  attr :label, :string, required: true
  attr :expanded, :boolean, default: false

  defp tree_toggle(assigns) do
    ~H"""
    <button
      type="button"
      phx-click={toggle_branch(@target)}
      aria-expanded={to_string(@expanded)}
      aria-controls={@target}
      aria-label={@label}
      class="shrink-0 p-0.5 text-stone-400 hover:text-stone-700 rounded"
    >
      <span
        id={"#{@target}-chevron"}
        class={["inline-flex transition-transform", @expanded && "rotate-90"]}
      >
        <.icon name="hero-chevron-right" class="w-4 h-4" />
      </span>
    </button>
    """
  end

  # Toggles a branch body (`#target`) and rotates its chevron (`#target-chevron`),
  # keeping the two in sync client-side without tracking expanded state on the
  # server.
  defp toggle_branch(target) do
    Phoenix.LiveView.JS.toggle(to: "##{target}")
    |> Phoenix.LiveView.JS.toggle_class("rotate-90", to: "##{target}-chevron")
  end
end
