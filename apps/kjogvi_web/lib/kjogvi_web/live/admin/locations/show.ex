defmodule KjogviWeb.Live.Admin.Locations.Show do
  @moduledoc """
  Admin page for a single common location: details (including its eBird match,
  when any), ancestors, its common children, and the edit / add sub-location /
  delete actions. Only common (unowned) locations resolve here; the checklists
  count spans all users.
  """

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    location =
      case Geo.common_location_by_slug(slug) do
        nil ->
          nil

        loc ->
          loc
          |> Location.Query.put_levels()
          |> Repo.preload([:special_parent_locations, :ebird_location])
      end

    if location do
      checklists_count = Geo.checklists_count(location.id)

      # Deletability counts *all* descendants (any user's locations may hang
      # under a common one), not just the common children listed on the page.
      can_delete =
        Geo.children_count(location.id) == 0 and checklists_count == 0 and
          is_nil(location.ebird_location)

      {:ok,
       socket
       |> assign(:page_title, location.name_en)
       |> assign(:location, location)
       |> assign(:ancestors, Geo.ancestor_locations(location))
       |> assign(:checklists_count, checklists_count)
       |> assign(:children, Geo.common_direct_children(location))
       |> assign(:can_delete, can_delete)
       |> assign(:ebird_entry, ebird_entry(location))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Location not found")
       |> redirect(to: ~p"/admin/locations")}
    end
  end

  # The country's eBird match entry (code + derived status) — present even
  # while the eBird country row is unlinked (the code-pass would-be match).
  defp ebird_entry(%Location{location_type: :country} = location) do
    Geo.Ebird.statuses_for_common_countries([location])[location.id]
  end

  defp ebird_entry(_location), do: nil

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Geo.delete_location(socket.assigns.current_scope, socket.assigns.location) do
      {:ok, _location} ->
        {:noreply,
         socket
         |> put_flash(:info, "Location deleted")
         |> push_navigate(to: ~p"/admin/locations")}

      {:error, :has_children} ->
        {:noreply, put_flash(socket, :error, "Cannot delete: location has sub-locations")}

      {:error, :has_checklists} ->
        {:noreply, put_flash(socket, :error, "Cannot delete: location has checklists")}

      {:error, :has_ebird_link} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "Cannot delete: an eBird region links here — unlink it in the workbench first"
         )}

      {:error, :forbidden} ->
        {:noreply, put_flash(socket, :error, "Only common locations can be deleted here")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Could not delete location")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <%!-- Breadcrumbs --%>
      <nav id="location-breadcrumbs" class="text-sm text-stone-500">
        <.breadcrumb_link href={~p"/admin/locations"}>Common Locations</.breadcrumb_link>
        <%= for ancestor <- @ancestors do %>
          <span class="mx-1 text-stone-400">/</span>
          <.breadcrumb_link
            href={~p"/admin/locations/#{ancestor.slug}"}
            phx-no-format
          >{ancestor.name_en}</.breadcrumb_link>
        <% end %>
        <span class="mx-1 text-stone-400">/</span>
        <span class="text-stone-700">{@location.name_en}</span>
      </nav>

      <%!-- Header + stats --%>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <.h1 class={[
            "mb-0!",
            @location.disabled &&
              "inline-flex items-center gap-1 bg-stone-200 text-stone-500! px-3 py-1 rounded-lg"
          ]}>
            <.disabled_marker :if={@location.disabled} class="w-6 h-6 align-middle" />
            {@location.name_en}
            <%= if @location.is_private do %>
              <span title="Private">
                <.icon name="hero-lock-closed" class="w-6 h-6 text-stone-500 align-middle" />
              </span>
            <% end %>
          </.h1>
          <p
            :if={Location.long_name(:private, @location) != @location.name_en}
            id="location-full-name"
            class="mt-2 text-lg text-stone-600"
          >
            {Location.long_name(:private, @location)}
          </p>
          <div class="mt-6 flex flex-wrap items-center gap-2">
            <.action_button
              :if={@location.location_type != :special}
              id="edit-location-button"
              navigate={~p"/admin/locations/#{@location.slug}/edit"}
              icon="hero-pencil-square"
              variant="secondary"
            >
              Edit
            </.action_button>
            <.action_button
              :if={Location.hierarchy_parent?(@location)}
              id="add-sub-location-button"
              navigate={~p"/admin/locations/new?parent_id=#{@location.id}"}
              icon="hero-plus"
              variant="secondary"
            >
              Add sub-location
            </.action_button>
            <button
              id="delete-location-button"
              type="button"
              phx-click="delete"
              data-confirm={"Delete location \"#{@location.name_en}\"? This cannot be undone."}
              disabled={!@can_delete}
              title={
                if @can_delete,
                  do: "Delete this location",
                  else:
                    "Cannot delete: location has sub-locations, checklists, or an eBird region link"
              }
              class="inline-flex items-center gap-2 rounded-lg px-4 py-2 text-sm font-semibold bg-rose-600 text-white hover:bg-rose-700 disabled:bg-stone-300 disabled:cursor-not-allowed disabled:hover:bg-stone-300"
            >
              <.icon name="hero-trash" class="w-4 h-4" /> Delete
            </button>
          </div>
          <p
            :if={@location.import_source}
            id="location-import-source"
            class="mt-4 text-sm text-stone-400"
          >
            Imported from: {Kjogvi.Types.ImportSource.label(@location.import_source)}
          </p>
        </div>

        <div id="location-stats" class="flex flex-wrap gap-2 mb-1">
          <div
            :if={@checklists_count > 0}
            id="location-checklists-count"
            class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg"
          >
            <span class="text-lg font-header font-bold tracking-tight">
              {@checklists_count}
            </span>
            <span class="text-forest-100 text-sm font-medium">checklists</span>
          </div>
          <div
            :if={@children != []}
            class="inline-flex items-baseline gap-2 bg-stone-600 text-white px-3 py-2 rounded-lg"
          >
            <span class="text-lg font-header font-bold tracking-tight">
              {length(@children)}
            </span>
            <span class="text-stone-200 text-sm font-medium">sub-locations</span>
          </div>
        </div>
      </div>

      <%!-- Location details --%>
      <div id="location-details" class="border border-stone-200 rounded-lg p-4">
        <div class="flex flex-wrap items-center gap-x-6 gap-y-3">
          <div>
            <dt class="text-xs font-medium text-stone-400 uppercase tracking-wider">Slug</dt>
            <dd class="mt-0.5 text-sm text-stone-800 font-mono">{@location.slug}</dd>
          </div>

          <.disabled_badge :if={@location.disabled} />

          <div :if={@location.iso_code && @location.iso_code != ""}>
            <dt class="text-xs font-medium text-stone-400 uppercase tracking-wider">ISO</dt>
            <dd class="mt-0.5 text-sm text-stone-800 font-mono font-semibold">
              {String.upcase(@location.iso_code)}
            </dd>
          </div>

          <.type_badge :if={@location.location_type} type={@location.location_type} />

          <div :if={@location.lat && @location.lon}>
            <dt class="text-xs font-medium text-stone-400 uppercase tracking-wider">
              Coordinates
            </dt>
            <dd class="mt-0.5 text-sm text-stone-800 font-mono">
              {@location.lat}, {@location.lon}
            </dd>
          </div>

          <div :if={@location.ebird_location} id="location-ebird-code">
            <dt class="text-xs font-medium text-stone-400 uppercase tracking-wider">eBird</dt>
            <dd class="mt-0.5 text-sm font-mono">
              <.link
                href={~p"/admin/ebird/locations/#{@location.ebird_location.country_code}"}
                phx-no-format
              >{@location.ebird_location.code}</.link>
            </dd>
          </div>

          <.link
            :if={@ebird_entry}
            id="location-ebird-status"
            navigate={~p"/admin/ebird/locations/#{@ebird_entry.code}"}
            title="eBird matching workbench"
            class="no-underline"
          >
            <.ebird_status_badge status={@ebird_entry.status} />
          </.link>

          <div
            :for={parent <- @location.special_parent_locations}
            id={"special-parent-badge-#{parent.id}"}
          >
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-sky-100 text-sky-700 rounded-full">
              <.icon name="hero-map" class="w-3 h-3 mr-1" />{parent.name_en}
            </span>
          </div>

          <.lifelist_badge :if={Location.show_on_lifelist?(@location)} />
        </div>
      </div>

      <%!-- Static map --%>
      <.static_map
        id="location-map"
        lat={@location.lat}
        lon={@location.lon}
        alt={"Map showing location of #{@location.name_en}"}
      />

      <%!-- Ancestry chain --%>
      <div :if={length(@ancestors) > 0} id="location-ancestry" class="space-y-2">
        <.h2 class="mb-3!">Ancestry</.h2>

        <ul class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <li :for={ancestor <- @ancestors} class="px-4 py-2.5">
            <.location_row location={ancestor} admin={true} />
          </li>
        </ul>
      </div>

      <%!-- Children --%>
      <div :if={@children != []} id="location-children">
        <.h2 class="mb-3!">Sub-locations</.h2>

        <ul class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <li :for={child <- @children} class="px-4 py-2.5">
            <.location_row location={child} admin={true} />
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
