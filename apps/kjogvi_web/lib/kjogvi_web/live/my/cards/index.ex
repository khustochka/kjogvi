defmodule KjogviWeb.Live.My.Cards.Index do
  @moduledoc false

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
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    # TODO: validate page number; redirect to default if number is 1
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    cards =
      Birding.get_cards(assigns.current_scope.user, %{page: page, page_size: @cards_per_page})

    {
      :noreply,
      socket
      |> assign(:cards, cards)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      Cards
    </.h1>

    <CoreComponents.table id="cards" rows={@cards}>
      <:col :let={card} label="id">
        <.link navigate={~p"/my/cards/#{card.id}"}>{card.id}</.link>
      </:col>
      <:col :let={card} label="Location">
        {Geo.Location.long_name(card.location)}
      </:col>
      <:col :let={card} label="Date">{format_date(card.observ_date)}</:col>
      <:col :let={card} label="Start time">{format_time(card.start_time)}</:col>
      <:col :let={card} label="Effort">{card.effort_type}</:col>
      <:col :let={card} label="M/L">
        <span :if={card.motorless} title="Motorless">
          <.icon name="fa-solid-bicycle" />
        </span>
      </:col>
      <:col :let={card} label="Obs">
        <span class="tabular-nums">
          {card.observation_count}
        </span>
      </:col>
    </CoreComponents.table>

    {paginate(@socket, @cards, &paginated_card_path/4, [:index], live: true)}
    """
  end

  defp paginated_card_path(_conn, _action, page, _params) do
    case page do
      1 -> ~p"/my/cards"
      n -> ~p"/my/cards/page/#{n}"
    end
  end
end
