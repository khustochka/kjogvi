defmodule KjogviWeb.Live.Components.Autocomplete do
  @moduledoc """
  Autocomplete picker: search field + dropdown of results.

  Owns search results, dropdown visibility, and the highlighted index.
  Two messages carry the selection and clear out of the component:

      {:autocomplete_select, on_select_event,
        %{"result" => result, ...on_select_params}}

      {:autocomplete_clear, on_select_event, on_select_params}

  ## Where the selection is delivered (`:notify_to`)

  By default both messages go to the **root LiveView** via `send/2`,
  landing in its `handle_info/2`. This is right when the autocomplete
  sits directly in a LiveView (the common case).

  When the autocomplete is nested inside another `LiveComponent`, that
  component has no `handle_info/2` and `send(self(), …)` would bypass it
  entirely (`self()` is the root process). Pass
  `notify_to={{Module, id}}` to instead route both messages into that
  component's `update/2` via `send_update/3`, as the assigns
  `:autocomplete_select` / `:autocomplete_clear` (each a map with
  `:event` and `:params`). The component handles them in `update/2`.

  ## Clearing the field after a pick (`:clear_on_select`)

  By default the field shows the committed `:input_value` after a
  selection — the single-value picker behaviour. Pass
  `clear_on_select` for a multi-select host (e.g. one that appends each
  pick to a list): the field empties after each pick so the user can
  search the next item. Pair it with `keep_focus_on_select`, which keeps
  focus in the field after an Enter commit instead of blurring, for a
  keep-typing picker.

  `:autocomplete_clear` fires when the user clears the field while a
  selection was in effect — via the × button, by deleting the text to
  empty, or by clicking away with an empty field. Escape is treated as
  *abandon* (revert to the committed value) and does not notify the
  parent. Click-away is treated as clear when the field is empty,
  abandon otherwise.

  Result rendering is delegated to a `:result` slot which receives the
  result struct and the current search term (so the caller can use
  `Autocomplete.Highlight.highlighted_text/1` if it wants matched-term
  emphasis):

      <:result :let={%{result: r, term: term}}>
        <Highlight.highlighted_text text={r.long_name} term={term} />
      </:result>

  Pass `:hidden_name` and `:hidden_value` to render a hidden form input
  alongside the search field; the selected id then rides along with any
  enclosing form submit.

  ## Search functions

  `:search_fn` accepts:
    * `fn query -> [results] end`
    * `{Module, :function}` — called as `Module.function(query)`
    * `{Module, :function, args}` — called as `Module.function(args ++ [query])`

  Failures inside the search function are swallowed and reported as
  empty results.
  """

  use KjogviWeb, :live_component

  alias KjogviWeb.CoreComponents
  alias KjogviWeb.Live.Components.Autocomplete.SearchInput

  # `attr` on a LiveComponent gives compile-time validation at call sites
  # (required attrs, types, unknown-attr warnings) but does NOT apply
  # defaults at runtime — the HEEx compiler can't see the LC's attrs from
  # `<.live_component module={...}>`. Defaults are applied below in
  # update/2 via assign_new. Keep both layers in sync.
  attr :id, :string, required: true
  attr :label, :string, default: nil
  attr :placeholder, :string, default: "Search..."
  attr :input_value, :string, default: ""

  # Optional hidden form input rendered alongside the search field. When
  # `:hidden_name` is set, the autocomplete carries the selected id with
  # any enclosing form submit.
  attr :hidden_name, :string, default: nil
  attr :hidden_value, :any, default: ""

  attr :search_fn, :any, required: true
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}

  # Where selection/clear are delivered. `nil` → the root LiveView via
  # `send/2`; `{Module, id}` → that LiveComponent's `update/2` via
  # `send_update/3`.
  attr :notify_to, :any, default: nil

  # When true, the field empties after a pick (multi-select host) instead
  # of showing the committed `:input_value`.
  attr :clear_on_select, :boolean, default: false

  # When true, pressing Enter to commit a result leaves focus in the
  # search field (rather than blurring) so the user can keep picking.
  # Read by the `AutocompletePicker` JS hook. Pairs naturally with
  # `:clear_on_select` for a multi-select host.
  attr :keep_focus_on_select, :boolean, default: false

  attr :debounce, :string, default: "300"
  attr :min_length, :integer, default: 2
  attr :compact, :boolean, default: false
  attr :errors, :list, default: []

  slot :result, required: true

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:search_results, [])
     |> assign(:search_term, nil)
     |> assign(:is_open, false)
     |> assign(:highlighted_index, 0)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:debounce, fn -> "300" end)
     |> assign_new(:min_length, fn -> 2 end)
     |> assign_new(:on_select_params, fn -> %{} end)
     |> assign_new(:errors, fn -> [] end)
     |> assign_new(:compact, fn -> false end)
     |> assign_new(:input_value, fn -> "" end)
     |> assign_new(:label, fn -> nil end)
     |> assign_new(:placeholder, fn -> "Search..." end)
     |> assign_new(:hidden_name, fn -> nil end)
     |> assign_new(:hidden_value, fn -> "" end)
     |> assign_new(:notify_to, fn -> nil end)
     |> assign_new(:clear_on_select, fn -> false end)
     |> assign_new(:keep_focus_on_select, fn -> false end)}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    if query == socket.assigns.search_term do
      {:noreply, socket}
    else
      results =
        if String.length(query) >= socket.assigns.min_length do
          execute_search(socket.assigns.search_fn, query)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:search_term, query)
       |> assign(:search_results, results)
       |> assign(:is_open, results != [])
       |> assign(:highlighted_index, 0)}
    end
  end

  def handle_event("focus", _params, socket) do
    {:noreply, assign(socket, :is_open, socket.assigns.search_results != [])}
  end

  # Escape and click-away. Reverts the field to the committed value,
  # but if the user had emptied the field first the gesture is treated
  # as a deselect.
  def handle_event("abandon", _params, socket) do
    cleared? = socket.assigns.search_term == "" and has_selection?(socket)
    if cleared?, do: send_clear(socket)
    {:noreply, reset_search(socket, cleared?)}
  end

  # Explicit × button (or any phx-click pushing the on_clear event).
  # Always notifies the parent if there was a committed selection.
  def handle_event("clear", _params, socket) do
    cleared? = has_selection?(socket)
    if cleared?, do: send_clear(socket)
    {:noreply, reset_search(socket, cleared?)}
  end

  def handle_event("select_result", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    do_select(socket, Enum.at(socket.assigns.search_results, index))
  end

  def handle_event("nav_select", _params, socket) do
    do_select(socket, Enum.at(socket.assigns.search_results, socket.assigns.highlighted_index))
  end

  def handle_event("nav", %{"direction" => "down"}, socket) do
    max_index = length(socket.assigns.search_results) - 1
    new_index = min(socket.assigns.highlighted_index + 1, max_index)
    {:noreply, set_highlight(socket, new_index)}
  end

  def handle_event("nav", %{"direction" => "up"}, socket) do
    new_index = max(socket.assigns.highlighted_index - 1, 0)
    {:noreply, set_highlight(socket, new_index)}
  end

  def handle_event("highlight_result", %{"index" => index}, socket) do
    {:noreply, assign(socket, :highlighted_index, index)}
  end

  defp do_select(socket, nil), do: {:noreply, reset_search(socket)}

  defp do_select(socket, result) do
    event_params = Map.put(socket.assigns.on_select_params, "result", result)
    notify_select(socket, event_params)

    {:noreply, reset_search(socket, socket.assigns.clear_on_select)}
  end

  # When `cleared?` is true, keep `search_term` as `""` instead of
  # `nil` so the field renders empty until the parent's re-render with
  # the cleared `input_value` arrives. Otherwise `display_value` would
  # briefly show the stale committed value between abandon and the
  # async `:autocomplete_clear` message.
  defp reset_search(socket, cleared? \\ false) do
    socket
    |> assign(:search_term, if(cleared?, do: "", else: nil))
    |> assign(:search_results, [])
    |> assign(:is_open, false)
    |> assign(:highlighted_index, 0)
  end

  defp has_selection?(socket) do
    socket.assigns.input_value not in [nil, ""]
  end

  defp notify_select(socket, params) do
    notify(socket, :autocomplete_select, params)
  end

  defp send_clear(socket) do
    notify(socket, :autocomplete_clear, socket.assigns.on_select_params)
  end

  # Deliver a selection/clear out of the component, either to the root
  # LiveView (`send/2`) or — when `:notify_to` names a component — into
  # that component's `update/2` (`send_update/3`).
  defp notify(socket, kind, params) do
    event = socket.assigns.on_select_event

    case socket.assigns.notify_to do
      {module, id} ->
        send_update(module, [{:id, id}, {kind, %{event: event, params: params}}])

      _ ->
        send(self(), {kind, event, params})
    end
  end

  defp set_highlight(socket, new_index) do
    socket
    |> assign(:highlighted_index, new_index)
    |> push_event("#{socket.assigns.id}:highlight", %{index: new_index})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-click-away={JS.push("abandon", target: @myself)}>
      <label
        :if={@label}
        for={@id}
        class="block text-sm font-semibold leading-6 text-zinc-800"
      >
        {@label}
      </label>
      <div class={["relative", @label && !@compact && "mt-2"]}>
        <SearchInput.search_input
          id={@id}
          target={@myself}
          on_search="search"
          on_clear="clear"
          placeholder={@placeholder}
          value={display_value(@search_term, @input_value)}
          debounce={@debounce}
          compact={@compact}
          has_errors={@errors != []}
          hook="AutocompletePicker"
          phx-focus="focus"
          data-keep-focus-on-select={@keep_focus_on_select && "true"}
        />
        <input :if={@hidden_name} type="hidden" name={@hidden_name} value={@hidden_value} />
        <div
          :if={@is_open and @search_results != []}
          id={"#{@id}-results"}
          tabindex="-1"
          class="absolute top-full left-0 right-0 z-10 mt-1 border border-gray-300 rounded-lg shadow-lg max-h-48 overflow-y-auto bg-white divide-y divide-gray-200"
        >
          <div
            :for={{result, index} <- Enum.with_index(@search_results)}
            id={"#{@id}-result-#{index}"}
            class={[
              "px-3 py-2 cursor-pointer text-sm",
              index == @highlighted_index && "bg-blue-100"
            ]}
            tabindex="-1"
            data-result-index={index}
            data-highlighted={index == @highlighted_index}
            phx-click="select_result"
            phx-value-index={index}
            phx-target={@myself}
          >
            {render_slot(@result, %{result: result, term: @search_term})}
          </div>
        </div>
      </div>
      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>
    </div>
    """
  end

  defp display_value(nil, current_value), do: current_value || ""
  defp display_value(search_term, _current_value), do: search_term

  defp execute_search(search_fn, query) when is_function(search_fn, 1) do
    search_fn.(query)
  rescue
    _ -> []
  end

  defp execute_search({module, function}, query) when is_atom(module) and is_atom(function) do
    apply(module, function, [query])
  rescue
    _ -> []
  end

  defp execute_search({module, function, args}, query)
       when is_atom(module) and is_atom(function) and is_list(args) do
    apply(module, function, args ++ [query])
  rescue
    _ -> []
  end

  defp execute_search(_search_fn, _query), do: []
end
