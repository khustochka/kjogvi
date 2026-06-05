defmodule KjogviWeb.Live.Components.ImageObservations do
  @moduledoc """
  Observation picker for the image add/edit forms.

  Lets the user attach observations to an image. It owns three things:

    * the list of currently selected observations, shown as removable tiles;
    * a date field (prefilled by the parent — from EXIF/last card on add, or
      the attached observations' date on edit);
    * a search box that, as the user types, resolves the text to matching taxa
      and lists *the user's observations* of those taxa directly in a dropdown.
      With a date set, results are restricted to that day; with the date empty,
      the most recent matching observations are shown.

  Selection state lives here; the component notifies the parent LiveView of the
  current selection with

      {:image_observations_changed, [observation_id]}

  so the parent can persist it (right after `create_image` on add, or on save on
  edit). The parent owns persistence; this component only stages the selection.

  ## Same-card locking

  All linked observations of an image must belong to the same card (ultimately
  enforced by `Kjogvi.Images.attach_observations/2`). The picker enforces this
  up front: once the first observation is selected its card is *locked in*, and
  while anything is selected

    * the date field is filled with that card's date and disabled — the user
      can't search a different day, so a date mismatch can't arise through the
      UI; and
    * search is scoped to that one card, so every result is addable.

  Removing the last selected observation unlocks the card: the date field
  becomes editable again and search returns to the date/recent scope.

  ## Relationship to `Autocomplete`

  The search box, dropdown, open/close, click-away, and min-length here partly
  duplicate `KjogviWeb.Live.Components.Autocomplete` (term highlighting reuses
  the shared `Autocomplete.Highlight`, so that part is not duplicated).
  This was a deliberate (if regrettable) divergence: `Autocomplete` is built to
  pick a *single* value into a hidden form input and emits its selection to the
  *root* LiveView via `send(self(), …)`. This picker instead **appends many**
  observations to a staged list, renders **disabled rows** (already-added) with
  reasons, and carries an adjacent **date** field — and as a LiveComponent it
  can't receive `Autocomplete`'s root-targeted message cleanly. Reusing only
  `SearchInput` was the pragmatic middle ground.

  TODO: fold this back onto `Autocomplete` (extending it for multi-select +
  disabled rows + component-targeted selection), which would also restore the
  keyboard navigation this hand-rolled dropdown currently lacks.
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Images
  alias KjogviWeb.ImageComponents
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_results, [])
     |> assign(:search_term, "")
     |> assign(:is_open, false)}
  end

  @impl true
  def update(assigns, socket) do
    # `selected` is the list of hydrated observation structs the parent has
    # staged; `date` is the (optional) Date the search is scoped to. Both are
    # owned by the parent and passed in on each render.
    {:ok,
     socket
     |> assign_new(:selected, fn -> [] end)
     |> assign_new(:date, fn -> nil end)
     |> assign(assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} class="space-y-4">
      <h2 class="text-sm font-semibold uppercase tracking-wide text-stone-500">Observations</h2>

      <ul
        :if={@selected != []}
        id={"#{@id}-selected"}
        class="grid grid-cols-1 gap-2 sm:grid-cols-2"
        aria-label="Selected observations"
      >
        <li :for={obs <- @selected} id={"#{@id}-selected-#{obs.id}"}>
          <ImageComponents.observation_tile
            observation={obs}
            on_remove="remove_observation"
            target={@myself}
          />
        </li>
      </ul>

      <p :if={@selected == []} class="text-sm text-stone-500">
        No observations attached yet.
      </p>

      <div class="flex flex-col gap-2 rounded-xl border border-stone-200 bg-stone-50 p-4 sm:flex-row sm:items-start sm:gap-4">
        <div class="w-44 shrink-0">
          <label for={"#{@id}-date"} class="block text-sm font-semibold leading-6 text-zinc-800">
            Date
          </label>
          <input
            type="date"
            id={"#{@id}-date"}
            name="date"
            value={date_value(locked_date(@selected) || @date)}
            disabled={@selected != []}
            phx-change="date_changed"
            phx-target={@myself}
            class="block w-full rounded-lg border-zinc-300 text-zinc-900 focus:border-zinc-400 focus:ring-0 disabled:cursor-not-allowed disabled:bg-stone-100 disabled:text-stone-500 sm:text-sm sm:leading-6"
          />
          <p :if={@selected != []} id={"#{@id}-date-locked"} class="mt-1 text-xs text-stone-400">
            Locked to the selected observation's card.
          </p>
        </div>

        <div
          class="relative w-full sm:max-w-md"
          phx-click-away={JS.push("close_dropdown", target: @myself)}
        >
          <label for={"#{@id}-search"} class="block text-sm font-semibold leading-6 text-zinc-800">
            Search observations
          </label>
          <SearchInput.search_input
            id={"#{@id}-search"}
            target={@myself}
            on_search="search"
            on_clear="clear_search"
            placeholder="Start typing a taxon name..."
            value={@search_term}
            phx-focus="open_dropdown"
          />

          <ul
            :if={@is_open and @search_results != []}
            id={"#{@id}-results"}
            class="absolute top-full left-0 right-0 z-10 mt-1 max-h-64 space-y-2 overflow-y-auto rounded-lg border border-gray-300 bg-white p-2 shadow-lg"
          >
            <li :for={obs <- @search_results} id={"#{@id}-result-#{obs.id}"}>
              <ImageComponents.observation_tile
                observation={obs}
                on_add={unless selected?(obs, @selected), do: "add_observation"}
                target={@myself}
                term={@search_term}
                class={selected?(obs, @selected) && "opacity-50"}
              />
              <p
                :if={selected?(obs, @selected)}
                class="px-3 pb-1 text-xs text-stone-400"
              >
                Already attached
              </p>
            </li>
          </ul>

          <p
            :if={@is_open and @search_results == [] and String.trim(@search_term) != ""}
            id={"#{@id}-no-results"}
            class="mt-1 text-sm text-stone-500"
          >
            No matching observations.
          </p>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("date_changed", %{"date" => date_string}, socket) do
    date = parse_date(date_string)

    {:noreply,
     socket
     |> assign(:date, date)
     |> rerun_search()}
  end

  def handle_event("search", %{"value" => query}, socket) do
    query = String.trim(query)

    {:noreply,
     socket
     |> assign(:search_term, query)
     |> assign(:is_open, true)
     |> run_search(query)}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_term, "")
     |> assign(:search_results, [])
     |> assign(:is_open, false)}
  end

  def handle_event("open_dropdown", _params, socket) do
    {:noreply, assign(socket, :is_open, socket.assigns.search_results != [])}
  end

  def handle_event("close_dropdown", _params, socket) do
    {:noreply, assign(socket, :is_open, false)}
  end

  def handle_event("add_observation", %{"observation-id" => id_string}, socket) do
    id = String.to_integer(id_string)
    result = Enum.find(socket.assigns.search_results, &(&1.id == id))

    if result && addable?(result, socket.assigns.selected) do
      selected = socket.assigns.selected ++ [result]
      notify_parent(selected)

      # The first pick locks the card; re-run the search so it narrows to that
      # card straight away.
      {:noreply,
       socket
       |> assign(:selected, selected)
       |> rerun_search()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("remove_observation", %{"observation-id" => id_string}, socket) do
    id = String.to_integer(id_string)
    selected = Enum.reject(socket.assigns.selected, &(&1.id == id))
    notify_parent(selected)

    # Removing the last pick unlocks the card; re-run so results widen again.
    {:noreply,
     socket
     |> assign(:selected, selected)
     |> rerun_search()}
  end

  # Don't search (or highlight) until the query is at least this long; a single
  # letter matches too much to be useful.
  @min_query_length 2

  defp rerun_search(socket) do
    run_search(socket, socket.assigns.search_term)
  end

  defp run_search(socket, query) do
    if String.length(String.trim(query)) < @min_query_length do
      socket
      |> assign(:search_results, [])
      |> assign(:is_open, false)
    else
      selected = socket.assigns.selected

      results =
        Images.search_observations_for_image(socket.assigns.current_user, %{
          query: query,
          # Once a card is locked in, search only it; otherwise scope by date.
          card_id: locked_card_id(selected),
          date: socket.assigns.date
        })

      assign(socket, :search_results, results)
    end
  end

  defp notify_parent(selected) do
    send(self(), {:image_observations_changed, Enum.map(selected, & &1.id)})
  end

  # A result can be added when it isn't already chosen. Once a card is locked,
  # search is already restricted to it, so every result is on the right card.
  defp addable?(obs, selected), do: not selected?(obs, selected)

  defp selected?(obs, selected), do: Enum.any?(selected, &(&1.id == obs.id))

  # The card of the first selected observation (all picks share one card). `nil`
  # when nothing is selected yet.
  defp locked_card_id([%{card_id: card_id} | _]), do: card_id
  defp locked_card_id(_), do: nil

  defp locked_date([%{card: %{observ_date: %Date{} = date}} | _]), do: date
  defp locked_date(_), do: nil

  defp date_value(%Date{} = date), do: Date.to_iso8601(date)
  defp date_value(_), do: ""

  defp parse_date(""), do: nil

  defp parse_date(string) do
    case Date.from_iso8601(string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
end
