defmodule KjogviWeb.Live.Components.AutocompleteSearch do
  @moduledoc """
  A self-contained autocomplete search component.

  Manages its own state (search results, dropdown visibility, current search term)
  and encapsulates the search logic. Communicates selected values to parent via
  `send(self(), msg)`.

  ## Attributes

  - `:label` - Display label for the input
  - `:id` - Unique component identifier
  - `:placeholder` - Placeholder text for search input
  - `:current_value` - Currently displayed value (from parent, shown when not searching)
  - `:hidden_name` - Form parameter name for the selected value
  - `:hidden_value` - The actual value to submit with form
  - `:search_fn` - Function for executing searches
  - `:on_select_event` - Event name sent to parent when value is selected
  - `:on_select_params` - Additional params to include in the selection message
  - `:errors` - List of error messages
  - `:debounce` - Milliseconds to debounce search (default: 300)

  ## Parent Communication

  When a result is selected, the component sends a message to the parent process:

      send(self(), {:autocomplete_select, "location_selected", %{"result" => result}})

  The parent handles this via `handle_info/2`:

      def handle_info({:autocomplete_select, "location_selected", params}, socket) do
        result = params["result"]
        # Handle the selected result
      end
  """

  use KjogviWeb, :live_component

  alias KjogviWeb.CoreComponents

  attr :label, :string, required: true
  attr :id, :string, required: true
  attr :placeholder, :string, default: "Search..."
  attr :current_value, :any, default: nil
  attr :hidden_name, :string, required: true
  attr :hidden_value, :any, default: ""
  attr :search_fn, :any, required: true
  attr :on_select_event, :string, required: true
  attr :on_select_params, :map, default: %{}
  attr :errors, :list, default: []
  attr :debounce, :string, default: "300"

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
     |> assign_new(:on_select_params, fn -> %{} end)
     |> assign_new(:errors, fn -> [] end)}
  end

  @impl true
  def handle_event("search", %{"value" => query}, socket) do
    if query == socket.assigns.search_term do
      {:noreply, socket}
    else
      results = execute_search(socket.assigns.search_fn, query)

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

  def handle_event("select_result", %{"index" => index_str}, socket) do
    index = String.to_integer(index_str)
    selected_result = Enum.at(socket.assigns.search_results, index)

    if selected_result do
      event_params = Map.put(socket.assigns.on_select_params, "result", selected_result)
      send(self(), {:autocomplete_select, socket.assigns.on_select_event, event_params})
    end

    {:noreply,
     socket
     |> assign(:search_term, nil)
     |> assign(:search_results, [])
     |> assign(:is_open, false)}
  end

  def handle_event("clear", _params, socket) do
    {:noreply,
     socket
     |> assign(:search_term, nil)
     |> assign(:search_results, [])
     |> assign(:is_open, false)
     |> assign(:highlighted_index, 0)}
  end

  def handle_event("nav", %{"direction" => "down"}, socket) do
    max_index = length(socket.assigns.search_results) - 1
    new_index = min(socket.assigns.highlighted_index + 1, max_index)

    {:noreply,
     socket
     |> assign(:highlighted_index, new_index)
     |> push_event("autocomplete:#{socket.assigns.id}:highlight", %{index: new_index})}
  end

  def handle_event("nav", %{"direction" => "up"}, socket) do
    new_index = max(socket.assigns.highlighted_index - 1, 0)

    {:noreply,
     socket
     |> assign(:highlighted_index, new_index)
     |> push_event("autocomplete:#{socket.assigns.id}:highlight", %{index: new_index})}
  end

  def handle_event("highlight_result", %{"index" => index}, socket) do
    {:noreply, assign(socket, :highlighted_index, index)}
  end

  def handle_event("nav_select", _params, socket) do
    selected_result = Enum.at(socket.assigns.search_results, socket.assigns.highlighted_index)

    if selected_result do
      event_params = Map.put(socket.assigns.on_select_params, "result", selected_result)
      send(self(), {:autocomplete_select, socket.assigns.on_select_event, event_params})
    end

    {:noreply,
     socket
     |> assign(:search_term, nil)
     |> assign(:search_results, [])
     |> assign(:is_open, false)
     |> assign(:highlighted_index, 0)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div phx-click-away={JS.push("clear", target: @myself)}>
      <label class="block text-sm font-semibold leading-6 text-zinc-800">{@label}</label>
      <div class="relative mt-2">
        <input
          type="search"
          id={@id}
          placeholder={@placeholder}
          phx-target={@myself}
          phx-hook=".AutocompleteInput"
          phx-keyup="search"
          phx-debounce={@debounce}
          phx-focus="focus"
          autocomplete="off"
          value={display_value(@search_term, @current_value)}
          class={[
            "mt-0 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
            @errors == [] && "border-zinc-300 focus:border-zinc-400",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
        />
        <input type="hidden" name={@hidden_name} value={@hidden_value} />
        <div
          :if={@is_open and @search_results != []}
          class="absolute top-full left-0 right-0 z-10 mt-1 border border-gray-300 rounded-lg shadow-lg max-h-48 overflow-y-auto bg-white divide-y divide-gray-200"
        >
          <div :for={{result, index} <- Enum.with_index(@search_results)}>
            <div
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
              {result_display(result)}
            </div>
          </div>
        </div>
      </div>
      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".AutocompleteInput">
        export default {
          mounted() {
            this.el.addEventListener("search", () => {
              if (!this.el.value) {
                this.pushEventTo(this.el, "clear", {})
              }
            })
            const navKeys = new Set(["ArrowDown", "ArrowUp", "Enter", "Escape", "Tab"])
            this.el.addEventListener("keydown", (e) => {
              if (e.key === "Escape") {
                this.pushEventTo(this.el, "clear", {})
              } else if (e.key === "ArrowDown") {
                e.preventDefault()
                this.pushEventTo(this.el, "nav", {direction: "down"})
              } else if (e.key === "ArrowUp") {
                e.preventDefault()
                this.pushEventTo(this.el, "nav", {direction: "up"})
              } else if (e.key === "Enter") {
                e.preventDefault()
                this.el.blur()
                this.pushEventTo(this.el, "nav_select", {})
              } else if (e.key === "Tab") {
                this.pushEventTo(this.el, "nav_select", {})
              }
            })
            this.el.addEventListener("keyup", (e) => {
              if (navKeys.has(e.key)) e.stopPropagation()
            })
            this.el.parentElement.addEventListener("mouseover", (e) => {
              const resultEl = e.target.closest("[data-result-index]")
              if (resultEl) {
                const index = parseInt(resultEl.dataset.resultIndex)
                this.pushEventTo(this.el, "highlight_result", {index})
              }
            })
            this.handleEvent(`autocomplete:${this.el.id}:highlight`, ({index}) => {
              const el = document.getElementById(`${this.el.id}-result-${index}`)
              if (el) el.scrollIntoView({block: "nearest"})
            })
          },
        }
      </script>
    </div>
    """
  end

  # When search_term is nil, show the current value from parent.
  # When search_term is a string (including ""), show what the user typed.
  defp display_value(nil, current_value), do: current_value || ""
  defp display_value(search_term, _current_value), do: search_term

  defp result_display(%{long_name: long_name}), do: long_name

  defp result_display(%{name_en: name_en, name_sci: name_sci}) when not is_nil(name_en) do
    "#{name_en} #{name_sci}"
  end

  defp result_display(result), do: inspect(result)

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
