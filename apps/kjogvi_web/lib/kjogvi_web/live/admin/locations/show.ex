defmodule KjogviWeb.Live.Admin.Locations.Show do
  @moduledoc """
  Admin page for a single common location: details, ancestors, and its common
  children, read-only. Only common (unowned) locations resolve here; the
  checklists count spans all users.
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
          |> Repo.preload(:special_parent_locations)
      end

    if location do
      {:ok,
       socket
       |> assign(:page_title, location.name_en)
       |> assign(:location, location)
       |> assign(:ancestors, Geo.ancestor_locations(location))
       |> assign(:checklists_count, Geo.checklists_count(location.id))
       |> assign(:children, Geo.common_direct_children(location))}
    else
      {:ok,
       socket
       |> put_flash(:error, "Location not found")
       |> redirect(to: ~p"/admin/locations")}
    end
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
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
          <.h1 class="mb-0!">
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
