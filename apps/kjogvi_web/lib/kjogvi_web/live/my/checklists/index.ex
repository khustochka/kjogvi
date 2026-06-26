defmodule KjogviWeb.Live.My.Checklists.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  import Scrivener.PhoenixView

  alias Kjogvi.Birding
  alias Kjogvi.Birding.ChecklistSearch.Filter
  alias KjogviWeb.Live.Components.ChecklistSearchFilter

  @cards_per_page 20

  @impl true
  def mount(_params, _session, socket) do
    {
      :ok,
      assign(socket, :page_title, "Checklists")
    }
  end

  # The URL is the single source of truth for the filter: it carries the filter
  # as query params (so a filtered view is linkable and survives reload/back),
  # and `handle_params` rebuilds the filter + taxon label from them on every nav.
  @impl true
  def handle_params(params, _url, socket) do
    page =
      Map.get(params, "page", "1")
      |> String.to_integer()

    {filter, taxon_label} = Birding.card_filter_from_params(params)

    {
      :noreply,
      socket
      |> assign(:page, page)
      |> assign(:filter, filter)
      |> assign(:taxon_label, taxon_label)
      |> load_cards()
    }
  end

  @impl true
  def handle_event("delete", %{"id" => id}, %{assigns: assigns} = socket) do
    checklist = Birding.fetch_card_for_edit(assigns.current_scope.current_user, id)

    case Birding.delete_card(checklist) do
      {:ok, _card} ->
        {
          :noreply,
          socket
          |> put_flash(:info, "Checklist ##{checklist.id} deleted.")
          |> load_cards()
        }

      {:error, :has_observations} ->
        {
          :noreply,
          put_flash(
            socket,
            :error,
            "Checklist ##{checklist.id} has observations and cannot be deleted."
          )
        }
    end
  end

  # Form change/submit both navigate to a new URL carrying the updated filter.
  # Only the form-owned fields (date, checkboxes, radios) are taken from the
  # params; the taxon and location are owned by the autocomplete components (via
  # handle_info) and are preserved from the current filter, so submitting the
  # form never clears them.
  def handle_event(event, %{"filter" => params}, socket)
      when event in ["filter_change", "filter_search"] do
    {:noreply, patch_to_filter(socket, merge_form_fields(socket.assigns.filter, params))}
  end

  def handle_event("filter_reset", _params, socket) do
    {:noreply, patch_to_filter(socket, %Filter{})}
  end

  # Taxon picked: set its key on the filter and navigate. The display label is
  # re-derived from the key in `handle_params`, so it survives a shared URL too.
  @impl true
  def handle_info({:autocomplete_select, "filter_taxon", %{"result" => taxon}}, socket) do
    {:noreply, patch_to_filter(socket, %{socket.assigns.filter | taxon_key: taxon.key})}
  end

  def handle_info({:autocomplete_clear, "filter_taxon", _params}, socket) do
    {:noreply, patch_to_filter(socket, %{socket.assigns.filter | taxon_key: nil})}
  end

  def handle_info({:autocomplete_select, "filter_location", %{"result" => location}}, socket) do
    {:noreply, patch_to_filter(socket, %{socket.assigns.filter | location: location})}
  end

  def handle_info({:autocomplete_clear, "filter_location", _params}, socket) do
    {:noreply, patch_to_filter(socket, %{socket.assigns.filter | location: nil})}
  end

  # Applying a filter always returns to page 1 of the (new) result set, encoded
  # into the URL so the view is linkable. `handle_params` does the actual search.
  defp patch_to_filter(socket, %Filter{} = filter) do
    push_patch(socket, to: ~p"/my/cards?#{Filter.to_params(filter)}")
  end

  # Updates only the form-owned fields of `filter` from submitted params,
  # leaving taxon/location (owned by the autocomplete components) intact.
  defp merge_form_fields(%Filter{} = filter, params) do
    %{
      filter
      | date: parse_date(params["date"]),
        include_subregions: checked?(params["include_subregions"]),
        unresolved: checked?(params["unresolved"]),
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
      Birding.search_cards(assigns.current_scope.current_user, assigns.filter, %{
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
        Checklists
      </.h1>
      <.action_button navigate={~p"/my/cards/new"} icon="hero-plus">New Checklist</.action_button>
    </div>

    <ChecklistSearchFilter.card_search_filter
      filter={@filter}
      user={@current_scope.current_user}
      scope={@current_scope}
      taxon_label={@taxon_label}
    />

    <p :if={Enum.empty?(@cards) and Filter.blank?(@filter)} class="text-stone-500">
      No cards yet.
    </p>
    <p :if={Enum.empty?(@cards) and not Filter.blank?(@filter)} class="text-stone-500">
      No cards match the current filter.
    </p>

    <.card_list id="checklists" cards={@cards} on_delete="delete" />

    <div class="mt-6">
      {paginate(@socket, @cards, paginated_card_path(@filter), [:index], live: true)}
    </div>
    """
  end

  # Page links carry the current filter as query params so paging preserves the
  # active search (and keeps each page linkable).
  defp paginated_card_path(%Filter{} = filter) do
    query = Filter.to_params(filter)

    fn _conn, _action, page, _params ->
      case page do
        1 -> ~p"/my/cards?#{query}"
        n -> ~p"/my/cards/page/#{n}?#{query}"
      end
    end
  end
end
