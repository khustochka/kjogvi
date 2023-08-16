defmodule KjogviWeb.CardLive.Index do
  use KjogviWeb, :live_view

  import Ecto.Query
  import Scrivener.PhoenixView

  alias Kjogvi.Schema.Card

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

    {:noreply,
     socket
     |> assign(:cards, get_cards(%{page: page}))
    }
  end

  defp get_cards(%{page: page}) do
    Card
    |> order_by([{:desc, :observ_date}, {:desc, :id}])
    |> preload(:location)
    |> Kjogvi.Repo.paginate(page: page, page_size: @cards_per_page)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.header>
    Cards
    </.header>

    <.table id="cards" rows={@cards}>
      <:col :let={card} label="id"><%= card.id %></:col>
      <:col :let={card} label="Location"><%= card.location.name_en %></:col>
      <:col :let={card} label="Date"><%= card.observ_date %></:col>
      <:col :let={card} label="Start time"><%= card.start_time %></:col>
      <:col :let={card} label="Effort"><%= card.effort_type %></:col>
    </.table>

    <%= paginate(@socket, @cards, &KjogviWeb.Router.Helpers.card_page_path/4, [:index], live: true) %>
    """
  end
end
