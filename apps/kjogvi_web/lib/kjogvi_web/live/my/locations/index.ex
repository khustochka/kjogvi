defmodule KjogviWeb.Live.My.Locations.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    locations = Geo.get_upper_level_locations()

    top_locations =
      locations
      |> Enum.filter(fn loc -> loc.ancestry == [] end)

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, locations)
      |> assign(:top_locations, top_locations)
      |> assign(:specials, Geo.get_specials())
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
  def render(assigns) do
    ~H"""
    <%!-- FIXME: Extract to partial --%>
    <.link patch={~p{/my/locations/countries}}>Countries</.link>
    <.link patch={~p{/my/locations}}>Locations</.link>

    <.header_single>
      Locations
    </.header_single>

    <div class="mb-3">
      <%= render_with_children(%{locations: @top_locations, all_locations: @locations}) %>
    </div>

    <h2 class="text-lg font-semibold">Special locations</h2>

    <ul>
      <%= for location <- @specials do %>
        <li>
          <div class="flex gap-2">
            <div><%= location.id %></div>
            <div><%= location.slug %></div>
            <div><%= location.name_en %></div>
            <div><%= location.cards_count %></div>
          </div>
        </li>
      <% end %>
    </ul>
    """
  end

  def render_with_children(assigns) do
    ~H"""
    <ul>
      <%= for location <- @locations do %>
        <li>
          <details open class="[&_svg]:open:-rotate-90">
          <summary class="flex gap-2">
            <svg class="rotate-0 transform text-blue-700 transition-all duration-300" fill="none" height="20" width="20" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2" viewBox="0 0 24 24">
              <polyline points="6 9 12 15 18 9"></polyline>
            </svg>
            <div><%= location.id %></div>
            <div><%= location.slug %></div>
            <div><%= location.name_en %></div>
            <div><%= location.cards_count %></div>
          </summary>
          <div class="ml-8">
            <%= render_with_children(%{
              locations:
                Enum.filter(@all_locations, fn loc -> List.last(loc.ancestry) == location.id end),
              all_locations: @all_locations
            }) %>
          </div>
          </details>
        </li>
      <% end %>
    </ul>
    """
  end
end
