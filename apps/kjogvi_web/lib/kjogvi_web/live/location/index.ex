defmodule KjogviWeb.LocationLive.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Birding

  @impl true
  def mount(_params, _session, socket) do
    locations = Birding.get_locations()

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
  def render(assigns) do
    ~H"""
    <.header>
      Locations
    </.header>

    <%= render_with_children(%{locations: @top_locations, all_locations: @locations}) %>

    <%!-- <.table id="locations" rows={@locations}>
      <:col :let={location} label="id"><%= location.id %></:col>
      <:col :let={location} label="slug"><%= location.slug %></:col>
      <:col :let={location} label="name"><%= location.name_en %></:col>
      <:col :let={location} label="type"><%= location.location_type %></:col>
      <:col :let={location} label="iso"><%= location.iso_code %></:col>
      <:col :let={location} label="private?"><%= location.is_private %></:col>
      <:col :let={location} label="5MR"><%= location.is_5mr %></:col>
      <:col :let={location} label="patch?"><%= location.is_patch %></:col>
    </.table> --%>
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
