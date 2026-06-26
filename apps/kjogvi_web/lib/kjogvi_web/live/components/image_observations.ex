defmodule KjogviWeb.Live.Components.ImageObservations do
  @moduledoc """
  Observation picker for the image add/edit forms.

  Lets the user attach observations to an image. It owns three things:

    * the list of currently selected observations, shown as removable tiles;
    * a date field (prefilled by the parent — from EXIF/last checklist on add, or
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

  An image must currently have at least one observation (a temporary product
  rule, also enforced by `Image.observations_changeset/2`). While nothing is
  selected the picker shows a standing "attach at least one" message and the
  parent's save is rejected.

  ## Same-checklist locking

  All linked observations of an image must belong to the same checklist (ultimately
  enforced by `Kjogvi.Images.attach_observations/2`). The picker enforces this
  up front: once the first observation is selected its checklist is *locked in*, and
  while anything is selected

    * the date field is filled with that checklist's date and disabled — the user
      can't search a different day, so a date mismatch can't arise through the
      UI; and
    * search is scoped to that one checklist, so every result is addable.

  Removing the last selected observation unlocks the checklist: the date field
  becomes editable again and search returns to the date/recent scope.

  ## Search via `Autocomplete`

  The search box, dropdown, keyboard navigation, click-away, and min-length are
  the shared `KjogviWeb.Live.Components.Autocomplete`. Because this is a nested
  `LiveComponent`, the autocomplete is told to deliver its selection back *here*
  (rather than to the root LiveView) with `notify_to={{__MODULE__, @id}}`; the
  pick then arrives in `update/2` as `:autocomplete_select`. `clear_on_select`
  empties the field after each pick so the next one can be searched, and the
  `search_fn` closure carries the current checklist-lock / date scope.

  The result rows are rendered by the `:result` slot as observation tiles.
  Already-attached observations are shown dimmed with an "Already attached"
  note; the autocomplete still wires them as clickable, but a re-pick is a
  no-op here (guarded by `addable?/2`).
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Images
  alias KjogviWeb.ImageComponents
  alias KjogviWeb.Live.Components.Autocomplete

  @impl true
  def update(%{autocomplete_select: %{params: %{"result" => obs}}}, socket) do
    {:ok, add_observation(socket, obs)}
  end

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

      <p
        :if={@selected == []}
        id={"#{@id}-required"}
        class="flex items-center gap-1.5 text-sm text-red-600"
        role="alert"
      >
        <.icon name="hero-exclamation-circle-mini" class="h-4 w-4 shrink-0" />
        Attach at least one observation before saving.
      </p>

      <div class="flex flex-col gap-2 rounded-xl border border-stone-200 bg-stone-50 p-4 sm:flex-row sm:items-start sm:gap-4">
        <div class="w-44 shrink-0">
          <label
            for={"#{@id}-date"}
            class="block text-sm font-medium font-header leading-6 text-zinc-800"
          >
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
            Locked to the selected observation's checklist.
          </p>
        </div>

        <div class="w-full sm:max-w-md">
          <.live_component
            module={Autocomplete}
            id={"#{@id}-search"}
            label="Search observations"
            placeholder="Start typing a taxon name..."
            search_fn={search_fn(@current_user, @selected, @date)}
            on_select_event="add_observation"
            notify_to={{__MODULE__, @id}}
            clear_on_select
            keep_focus_on_select
          >
            <:result :let={%{result: obs, term: term}}>
              <div class={selected?(obs, @selected) && "opacity-50"}>
                <ImageComponents.observation_tile observation={obs} term={term} variant={:result} />
                <p :if={selected?(obs, @selected)} class="pt-1 text-xs text-stone-400">
                  Already attached
                </p>
              </div>
            </:result>
          </.live_component>
        </div>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("date_changed", %{"date" => date_string}, socket) do
    {:noreply, assign(socket, :date, parse_date(date_string))}
  end

  def handle_event("remove_observation", %{"observation-id" => id_string}, socket) do
    id = String.to_integer(id_string)
    selected = Enum.reject(socket.assigns.selected, &(&1.id == id))
    notify_parent(selected)

    {:noreply, assign(socket, :selected, selected)}
  end

  # Don't search (or highlight) until the query is at least this long; a single
  # letter matches too much to be useful.
  @min_query_length 2

  # A closure the embedded `Autocomplete` calls with the typed query. Capturing
  # the current `selected`/`date` keeps the search scope (checklist lock or date) in
  # sync with what's staged. `Autocomplete` already gates on its own
  # `min_length`, but we keep the guard so the scope-resolving query never runs
  # on a too-short term.
  defp search_fn(user, selected, date) do
    fn query ->
      if String.length(String.trim(query)) < @min_query_length do
        []
      else
        Images.search_observations_for_image(user, %{
          query: query,
          # Once a checklist is locked in, search only it; otherwise scope by date.
          checklist_id: locked_checklist_id(selected),
          date: date
        })
      end
    end
  end

  defp add_observation(socket, obs) do
    if addable?(obs, socket.assigns.selected) do
      selected = socket.assigns.selected ++ [obs]
      notify_parent(selected)
      assign(socket, :selected, selected)
    else
      socket
    end
  end

  defp notify_parent(selected) do
    send(self(), {:image_observations_changed, Enum.map(selected, & &1.id)})
  end

  # A result can be added when it isn't already chosen. Once a checklist is locked,
  # search is already restricted to it, so every result is on the right checklist.
  defp addable?(obs, selected), do: not selected?(obs, selected)

  defp selected?(obs, selected), do: Enum.any?(selected, &(&1.id == obs.id))

  # The checklist of the first selected observation (all picks share one checklist). `nil`
  # when nothing is selected yet.
  defp locked_checklist_id([%{checklist_id: checklist_id} | _]), do: checklist_id
  defp locked_checklist_id(_), do: nil

  defp locked_date([%{checklist: %{observ_date: %Date{} = date}} | _]), do: date
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
