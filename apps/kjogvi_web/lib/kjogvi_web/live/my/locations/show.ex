defmodule KjogviWeb.Live.My.Locations.Show do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location

  @impl true
  def mount(%{"slug" => slug}, _session, socket) do
    location = Geo.location_by_slug_scope(socket.assigns.current_scope, slug)

    if location do
      ancestors = Location.ancestors(location)
      cards_count = Geo.cards_count(location.id)
      children = Geo.direct_children(location.id)
      member_locations = Geo.special_member_locations(location)

      {:ok,
       socket
       |> assign(:page_title, location.name_en)
       |> assign(:location, location)
       |> assign(:ancestors, ancestors)
       |> assign(:cards_count, cards_count)
       |> assign(:children, children)
       |> assign(:member_locations, member_locations)}
    else
      {:ok,
       socket
       |> put_flash(:error, "Location not found")
       |> redirect(to: ~p"/my/locations")}
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
        <.link href={~p"/my/locations"} class="text-forest-600 hover:underline no-underline">
          All locations
        </.link>
        <%= for ancestor <- @ancestors do %>
          <span class="mx-1 text-stone-400">/</span>
          <.link
            href={~p"/my/locations/#{ancestor.slug}"}
            class="text-forest-600 hover:underline no-underline"
          >
            {ancestor.name_en}
          </.link>
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
          <div class="flex flex-wrap items-center gap-x-3 gap-y-1 mt-1">
            <span class="text-sm text-stone-500 font-mono">{@location.slug}</span>
            <span
              :if={@location.iso_code && @location.iso_code != ""}
              class="text-stone-500 font-mono text-sm font-semibold"
            >
              {String.upcase(@location.iso_code)}
            </span>
            <.type_badge :if={@location.location_type} type={@location.location_type} />
          </div>
          <.link
            id="lifelist-link"
            href={~p"/my/lifelist/#{@location.slug}"}
            class="mt-2 inline-flex items-center gap-1 px-2.5 py-1 text-xs sm:text-sm font-medium text-forest-600 bg-forest-50 hover:bg-forest-100 rounded no-underline"
          >
            Lifelist
          </.link>
        </div>

        <div id="location-stats" class="flex flex-wrap gap-2 mb-1">
          <div class="inline-flex items-baseline gap-2 bg-forest-600 text-white px-3 py-2 rounded-lg">
            <span class="text-lg font-header font-bold tracking-tight">
              {@cards_count}
            </span>
            <span class="text-forest-100 text-sm font-medium">cards</span>
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
      <div
        :if={has_details?(@location)}
        id="location-details"
        class="border border-stone-200 rounded-lg p-4"
      >
        <div class="flex flex-wrap gap-x-6 gap-y-3">
          <div :if={@location.lat && @location.lon}>
            <dt class="text-xs font-medium text-stone-400 uppercase tracking-wider">
              Coordinates
            </dt>
            <dd class="mt-0.5 text-sm text-stone-800 font-mono">
              {@location.lat}, {@location.lon}
            </dd>
          </div>

          <div :if={@location.is_patch}>
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-amber-100 text-amber-700 rounded-full">
              <.icon name="hero-sparkles" class="w-3 h-3 mr-1" /> Patch
            </span>
          </div>

          <div :if={@location.is_5mr}>
            <span class="inline-flex items-center px-2 py-1 text-xs font-medium bg-sky-100 text-sky-700 rounded-full">
              <.icon name="hero-map" class="w-3 h-3 mr-1" /> 5-Mile Radius
            </span>
          </div>
        </div>
      </div>

      <%!-- Ancestry chain --%>
      <div :if={length(@ancestors) > 0} id="location-ancestry" class="space-y-2">
        <.h2 class="mb-3!">Ancestry</.h2>

        <div class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <%= for ancestor <- @ancestors do %>
            <div class="flex items-center justify-between gap-2 px-4 py-2.5">
              <.location_row location={ancestor} />
              <.lifelist_link slug={ancestor.slug} />
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Children --%>
      <div :if={@children != []} id="location-children">
        <.h2 class="mb-3!">Sub-locations</.h2>

        <div class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <%= for child <- @children do %>
            <div class="flex items-center justify-between gap-2 px-4 py-2.5">
              <.location_row location={child} />
              <.lifelist_link slug={child.slug} />
            </div>
          <% end %>
        </div>
      </div>

      <%!-- Member locations (for special locations) --%>
      <div :if={@member_locations != []} id="location-members">
        <.h2 class="mb-3!">Member locations</.h2>

        <div class="border border-stone-200 rounded-lg divide-y divide-stone-100">
          <%= for member <- @member_locations do %>
            <div class="flex items-center justify-between gap-2 px-4 py-2.5">
              <.location_row location={member} />
              <.lifelist_link slug={member.slug} />
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp has_details?(location) do
    (location.lat && location.lon) || location.is_patch || location.is_5mr
  end
end
