defmodule KjogviWeb.Live.My.Cards.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Birding
  alias Kjogvi.Birding.CardSearch.Filter
  alias KjogviWeb.Live.Components.CardSearchFilter

  @cards_per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      socket
      |> assign(:page_title, "Cards")
      |> assign(:filter, %Filter{})
      |> assign(:taxon_label, "")
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

  # Form change/submit both re-run the search. Only the form-owned fields
  # (date, checkboxes, radios) are taken from the params; the taxon and
  # location are owned by the autocomplete components (via handle_info) and are
  # preserved from the current filter, so submitting the form never clears them.
  def handle_event(event, %{"filter" => params}, socket)
      when event in ["filter_change", "filter_search"] do
    {:noreply, apply_filter(socket, merge_form_fields(socket.assigns.filter, params))}
  end

  def handle_event("filter_reset", _params, socket) do
    {
      :noreply,
      socket
      |> assign(:taxon_label, "")
      |> apply_filter(%Filter{})
    }
  end

  # Taxon picked: remember its display label and key, then re-search.
  @impl true
  def handle_info({:autocomplete_select, "filter_taxon", %{"result" => taxon}}, socket) do
    filter = %{socket.assigns.filter | taxon_key: taxon.key}

    {
      :noreply,
      socket
      |> assign(:taxon_label, taxon.name_en)
      |> apply_filter(filter)
    }
  end

  def handle_info({:autocomplete_clear, "filter_taxon", _params}, socket) do
    filter = %{socket.assigns.filter | taxon_key: nil}

    {
      :noreply,
      socket
      |> assign(:taxon_label, "")
      |> apply_filter(filter)
    }
  end

  def handle_info({:autocomplete_select, "filter_location", %{"result" => location}}, socket) do
    {:noreply, apply_filter(socket, %{socket.assigns.filter | location: location})}
  end

  def handle_info({:autocomplete_clear, "filter_location", _params}, socket) do
    {:noreply, apply_filter(socket, %{socket.assigns.filter | location: nil})}
  end

  # Applying a filter always returns to page 1 of the (new) result set.
  defp apply_filter(socket, %Filter{} = filter) do
    socket
    |> assign(:filter, filter)
    |> assign(:page, 1)
    |> load_cards()
  end

  # Updates only the form-owned fields of `filter` from submitted params,
  # leaving taxon/location (owned by the autocomplete components) intact.
  defp merge_form_fields(%Filter{} = filter, params) do
    %{
      filter
      | date: parse_date(params["date"]),
        include_subregions: checked?(params["include_subregions"]),
        exclude_subspecies: checked?(params["exclude_subspecies"]),
        voice: parse_voice(params["voice"]),
        hidden: checked?(params["hidden"])
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> date
      _ -> nil
    end
  end

  defp parse_voice("seen"), do: :seen
  defp parse_voice("heard_only"), do: :heard_only
  defp parse_voice(_), do: :all

  defp checked?("true"), do: true
  defp checked?(_), do: false

  defp load_cards(%{assigns: assigns} = socket) do
    cards =
      Birding.search_cards(assigns.current_scope.user, assigns.filter, %{
        page: assigns.page,
        page_size: @cards_per_page
      })

    assign(socket, :cards, cards)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mb-4 flex items-center justify-between gap-4">
      <.h1 class="mt-0! mb-0! leading-none">
        Cards
      </.h1>
      <.action_button navigate={~p"/my/cards/new"} icon="hero-plus">New Card</.action_button>
    </div>

    <CardSearchFilter.card_search_filter
      filter={@filter}
      user={@current_scope.user}
      taxon_label={@taxon_label}
    />

    <p :if={Enum.empty?(@cards) and Filter.blank?(@filter)} class="text-stone-500">
      No cards yet.
    </p>
    <p :if={Enum.empty?(@cards) and not Filter.blank?(@filter)} class="text-stone-500">
      No cards match the current filter.
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
