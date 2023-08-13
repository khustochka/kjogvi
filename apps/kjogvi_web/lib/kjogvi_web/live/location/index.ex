defmodule KjogviWeb.LocationLive.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Schema.Location

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Locations")
      |> assign(:locations, Location |> Kjogvi.Repo.all)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
    Locations
    </.header>

    <.table id="locations" rows={@locations}>
      <:col :let={location} label="id"><%= location.id %></:col>
      <:col :let={location} label="slug"><%= location.slug %></:col>
      <:col :let={location} label="name"><%= location.name_en %></:col>
      <:col :let={location} label="type"><%= location.location_type %></:col>
      <:col :let={location} label="iso"><%= location.iso_code %></:col>
      <:col :let={location} label="private?"><%= location.is_private %></:col>
      <:col :let={location} label="5MR"><%= location.is_5mr %></:col>
      <:col :let={location} label="patch?"><%= location.is_patch %></:col>
    </.table>
    """
  end
end
