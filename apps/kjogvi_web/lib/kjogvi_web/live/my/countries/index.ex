defmodule KjogviWeb.Live.My.Countries.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Geo

  @impl true
  def mount(_params, _session, socket) do
    countries = Geo.get_countries()

    {
      :ok,
      socket
      |> assign(:page_title, "Countries")
      |> assign(:countries, countries)
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
    <.link patch={~p{/my/locations/countries}}>Countries</.link>
    <.link patch={~p{/my/locations}}>Locations</.link>

    <.h1>
      Countries
    </.h1>

    <CoreComponents.table id="countries" rows={@countries}>
      <:col :let={country} label="id">{country.id}</:col>
      <:col :let={country} label="slug">{country.slug}</:col>
      <:col :let={country} label="name">{country.name_en}</:col>
      <:col :let={country} label="iso">{country.iso_code}</:col>
    </CoreComponents.table>
    """
  end
end
