defmodule KjogviWeb.Live.My.Cards.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Birding

  @cards_per_page 20

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
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    {
      :noreply,
      socket
      |> assign(:page, page)
      |> load_cards()
    }
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: assigns} = socket) do
    card = Birding.fetch_card_for_edit(assigns.current_scope.user, id)

    case Birding.delete_card(card) do
      {:ok, _card} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Card ##{card.id} deleted.")
          |> load_cards()
        }

      {:error, :has_observations} ->
        {
          :noreply,
          put_flash(socket, :error, "Card ##{card.id} has observations and cannot be deleted.")
        }
    end
  end

  defp load_cards(%{assigns: assigns} = socket) do
    cards =
      Birding.get_cards(assigns.current_scope.user, %{
        page: assigns.page,
        page_size: @cards_per_page
      })

    assign(socket, :cards, cards)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      Cards
    </.h1>

    <div class="mb-4 flex justify-end">
      <.action_button navigate={~p"/my/cards/new"} icon="hero-plus">New Card</.action_button>
    </div>

    <p :if={Enum.empty?(@cards)} class="text-stone-500">
      No cards yet.
    </p>

    <.card_list id="cards" cards={@cards} on_delete="delete" />

    <div class="mt-6">
      {paginate(@socket, @cards, &paginated_card_path/4, [:index], live: true)}
    </div>
    """
  end

  defp paginated_card_path(_conn, _action, page, _params) do
    case page do
      1 -> ~p"/my/cards"
      n -> ~p"/my/cards/page/#{n}"
    end
  end
end
