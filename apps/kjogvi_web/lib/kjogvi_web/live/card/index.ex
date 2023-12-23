defmodule KjogviWeb.Live.Card.Index do
  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Birding

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
    <.header>
      Cards
    </.header>

    <.table id="cards" rows={@cards}>
      <:col :let={card} label="id">
        <.link navigate={~p"/cards/#{card.id}"}><%= card.id %></.link>
      </:col>
      <:col :let={card} label="Location">
        <%= location_with_country(card.location) %>
      </:col>
      <:col :let={card} label="Date"><%= card.observ_date %></:col>
      <:col :let={card} label="Start time"><%= card.start_time %></:col>
      <:col :let={card} label="Effort"><%= card.effort_type %></:col>
      <:col :let={card} label="Obs">
        <span class="tabular-nums">
          <%= card.observation_count %>
        </span>
      </:col>
    </.table>

    <%= paginate(@socket, @cards, &KjogviWeb.Router.Helpers.card_page_path/4, [:index], live: true) %>
    """
  end

  defp location_with_country(location) do
    [location, location.country]
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.map(& &1.name_en)
    |> Enum.join(", ")
  end
end
