defmodule KjogviWeb.CardLive.Show do
  use KjogviWeb, :live_view

  alias Kjogvi.Birding

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
    }
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    card = Birding.fetch_card(id)

    {
      :noreply,
      socket
      |> assign(:page_title, "Card ##{card.id}")
      |> assign(:card, card)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
      Card #<%= @card.id %>
    </.header>
    <h2 class="py-4">Notes</h2>
    <p>
      <%= @card.notes %>
    </p>
    <h2 class="py-4">Observations</h2>
    <.table id="observation" rows={@card.observations}>
      <:col :let={obs} label="id"><%= obs.id %></:col>
      <:col :let={obs} label="Quantity"><%= obs.quantity %></:col>
      <:col :let={obs} label="Taxon"><%= obs.taxon.name_en %></:col>
      <:col :let={obs} label="Voice only"><%= obs.voice %></:col>
    </.table>
    """
  end
end
