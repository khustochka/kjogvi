defmodule KjogviWeb.LocationLive.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    locations = Geo.get_locations()

    top_locations =
      locations
      |> Enum.filter(fn loc -> loc.ancestry == [] end)

    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, locations)
      |> assign(:top_locations, top_locations)
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
    <.link patch={~p{/locations/countries}}>Countries</.link>
    <.link patch={~p{/locations}}>Locations</.link>

    <.header>
      Locations
    </.header>

    <%= render_with_children(%{locations: @top_locations, all_locations: @locations}) %>
    """
  end

  def render_with_children(assigns) do
    ~H"""
    <%= for location <- @locations do %>
      <div>
        <div class="flex gap-2">
          <div><%= location.id %></div>
          <div><%= location.slug %></div>
          <div><%= location.name_en %></div>
          <div><%= location.cards_count %></div>
        </div>
        <div class="ml-8">
          <%= render_with_children(%{
            locations:
              Enum.filter(@all_locations, fn loc -> List.last(loc.ancestry) == location.id end),
            all_locations: @all_locations
          }) %>
        </div>
      </div>
    <% end %>
    """
  end
end
