defmodule KjogviWeb.LifelistLive.Index do
  use KjogviWeb, :live_view

  alias Kjogvi.Birding

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Lifelist")
    }
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {
      :noreply,
      socket
      |> assign(:lifelist, Birding.lifelist)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Lifelist
    </.header>
    <p>
    Total of <%= length(@lifelist) %> taxa.
    </p>
    <.table id="lifers" rows={@lifelist}>
      <:col :let={lifer} label="Taxon"><%= lifer.taxon_key %></:col>
      <:col :let={lifer} label="Date"><%= lifer.observ_date %></:col>
      <:col :let={lifer} label="Time"><%= lifer.start_time %></:col>
      <:col :let={lifer} label="Location"><%= lifer.location.name_en %></:col>
    </.table>
    """
  end
end
