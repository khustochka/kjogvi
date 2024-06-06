defmodule KjogviWeb.Live.Card.Index do
  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Birding
  alias Kjogvi.Geo

  @cards_per_page 50

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Cards")
    }
  end

  @impl true
  def handle_params(params, _url, socket) do
    # TODO: validate page number; redirect to default if number is 1
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    {
      :noreply,
      socket
      |> assign(:cards, Birding.get_cards(%{page: page, page_size: @cards_per_page}))
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header_single>
      Cards
    </.header_single>

    <CoreComponents.table id="cards" rows={@cards}>
      <:col :let={card} label="id">
        <.link navigate={~p"/cards/#{card.id}"}><%= card.id %></.link>
      </:col>
      <:col :let={card} label="Location">
        <%= Geo.Location.long_name(card.location) %>
      </:col>
      <:col :let={card} label="Date"><%= card.observ_date %></:col>
      <:col :let={card} label="Start time"><%= card.start_time %></:col>
      <:col :let={card} label="Effort"><%= card.effort_type %></:col>
      <:col :let={card} label="M/L">
        <span :if={card.motorless} title="Motorless">
          <.icon name="hero-bug-ant" class="h-4 w-4" />
        </span>
      </:col>
      <:col :let={card} label="Obs">
        <span class="tabular-nums">
          <%= card.observation_count %>
        </span>
      </:col>
    </CoreComponents.table>

    <%= paginate(@socket, @cards, &KjogviWeb.Router.Helpers.card_page_path/4, [:index], live: true) %>
    """
  end
end
