defmodule KjogviWeb.Live.Components.MonthCalendar do
  @moduledoc """
  A month calendar component for selecting observation dates.

  Displays a calendar grid with month navigation, highlights days that have
  existing cards, and allows click-to-select. Communicates the selected date
  to the parent via `send(self(), {:calendar_select, ...})`.

  ## Attributes

  - `:id` - Unique component identifier
  - `:selected_date` - Currently selected date (Date or nil)
  - `:user` - The user whose cards to highlight
  - `:hidden_name` - Form parameter name for the date value
  - `:errors` - List of error messages
  - `:label` - Display label
  """

  use KjogviWeb, :live_component

  alias Kjogvi.Birding
  alias KjogviWeb.CoreComponents

  attr :id, :string, required: true
  attr :selected_date, :any, default: nil
  attr :user, :any, required: true
  attr :hidden_name, :string, required: true
  attr :errors, :list, default: []
  attr :label, :string, default: "Observation Date"

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:initialized, false)
     |> assign(:card_days, MapSet.new())
     |> assign(:today, Date.utc_today())}
  end

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:label, fn -> "Observation Date" end)
      |> assign_new(:errors, fn -> [] end)

    socket =
      if socket.assigns.initialized do
        # On subsequent updates, keep the displayed month but refresh card days
        socket
      else
        # First mount: derive displayed month from selected_date or today
        date = assigns[:selected_date] || Date.utc_today()

        socket
        |> assign(:displayed_year, date.year)
        |> assign(:displayed_month, date.month)
        |> assign(:initialized, true)
      end

    {:ok, load_card_days(socket)}
  end

  @impl true
  def handle_event("prev_month", _params, socket) do
    {year, month} = prev_month(socket.assigns.displayed_year, socket.assigns.displayed_month)

    socket =
      socket
      |> assign(:displayed_year, year)
      |> assign(:displayed_month, month)
      |> load_card_days()

    {:noreply, socket}
  end

  def handle_event("next_month", _params, socket) do
    {year, month} = next_month(socket.assigns.displayed_year, socket.assigns.displayed_month)

    socket =
      socket
      |> assign(:displayed_year, year)
      |> assign(:displayed_month, month)
      |> load_card_days()

    {:noreply, socket}
  end

  def handle_event("select_day", %{"day" => day_str}, socket) do
    day = String.to_integer(day_str)
    date = Date.new!(socket.assigns.displayed_year, socket.assigns.displayed_month, day)

    send(self(), {:calendar_select, "date_selected", %{"date" => date}})

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    weeks = calendar_weeks(assigns.displayed_year, assigns.displayed_month)
    month_name = month_name(assigns.displayed_month)

    assigns =
      assigns
      |> assign(:weeks, weeks)
      |> assign(:month_name, month_name)

    ~H"""
    <div id={@id}>
      <label class="block text-sm font-semibold leading-6 text-zinc-800">{@label}</label>
      <div class="mt-2 border border-zinc-300 rounded-lg p-3 w-fit">
        <div class="flex items-center justify-between mb-2">
          <button
            type="button"
            phx-click="prev_month"
            phx-target={@myself}
            class="p-1 hover:bg-zinc-100 rounded"
            aria-label="Previous month"
          >
            <.icon name="hero-chevron-left" class="w-4 h-4" />
          </button>
          <span class="text-sm font-semibold text-zinc-800" id={"#{@id}-month-label"}>
            {@month_name} {@displayed_year}
          </span>
          <button
            type="button"
            phx-click="next_month"
            phx-target={@myself}
            class="p-1 hover:bg-zinc-100 rounded"
            aria-label="Next month"
          >
            <.icon name="hero-chevron-right" class="w-4 h-4" />
          </button>
        </div>
        <table class="text-center text-sm">
          <thead>
            <tr>
              <th
                :for={day <- ~w(Mo Tu We Th Fr Sa Su)}
                class="w-8 py-1 text-xs text-zinc-500 font-normal"
              >
                {day}
              </th>
            </tr>
          </thead>
          <tbody>
            <tr :for={week <- @weeks}>
              <td :for={cell <- week} class="p-0">
                <.day_cell
                  cell={cell}
                  selected_date={@selected_date}
                  displayed_year={@displayed_year}
                  displayed_month={@displayed_month}
                  card_days={@card_days}
                  today={@today}
                  myself={@myself}
                />
              </td>
            </tr>
          </tbody>
        </table>
      </div>
      <input
        type="hidden"
        name={@hidden_name}
        id={"#{@id}-hidden"}
        value={if @selected_date, do: Date.to_iso8601(@selected_date), else: ""}
      />
      <CoreComponents.error :for={msg <- @errors}>{msg}</CoreComponents.error>
    </div>
    """
  end

  defp day_cell(%{cell: :empty} = assigns) do
    ~H"""
    <span class="block w-8 h-8"></span>
    """
  end

  defp day_cell(%{cell: {:day, day}} = assigns) do
    is_selected =
      assigns.selected_date != nil and
        assigns.selected_date.year == assigns.displayed_year and
        assigns.selected_date.month == assigns.displayed_month and
        assigns.selected_date.day == day

    has_card = MapSet.member?(assigns.card_days, day)

    is_today =
      assigns.today.year == assigns.displayed_year and
        assigns.today.month == assigns.displayed_month and
        assigns.today.day == day

    assigns =
      assigns
      |> assign(:day, day)
      |> assign(:is_selected, is_selected)
      |> assign(:has_card, has_card)
      |> assign(:is_today, is_today)

    ~H"""
    <button
      type="button"
      phx-click="select_day"
      phx-value-day={@day}
      phx-target={@myself}
      id={"day-#{@day}"}
      class={[
        "block w-8 h-8 rounded text-sm leading-8 cursor-pointer",
        @is_selected && "bg-teal-700 text-white font-bold",
        !@is_selected && @has_card && "bg-teal-100 text-teal-800",
        !@is_selected && !@has_card && @is_today && "text-red-600 font-semibold",
        !@is_selected && !@has_card && !@is_today && "hover:bg-zinc-100"
      ]}
    >
      {@day}
    </button>
    """
  end

  defp load_card_days(socket) do
    days =
      Birding.card_days_in_month(
        socket.assigns.user,
        socket.assigns.displayed_year,
        socket.assigns.displayed_month
      )

    assign(socket, :card_days, MapSet.new(days))
  end

  @doc false
  def calendar_weeks(year, month) do
    days_in_month = Date.days_in_month(Date.new!(year, month, 1))
    # Monday=1..Sunday=7
    start_weekday = Date.day_of_week(Date.new!(year, month, 1))
    leading = List.duplicate(:empty, start_weekday - 1)
    days = for d <- 1..days_in_month, do: {:day, d}
    all_cells = leading ++ days
    # Pad to full weeks
    trailing_count = rem(7 - rem(length(all_cells), 7), 7)
    all_cells = all_cells ++ List.duplicate(:empty, trailing_count)

    Enum.chunk_every(all_cells, 7)
  end

  defp prev_month(year, 1), do: {year - 1, 12}
  defp prev_month(year, month), do: {year, month - 1}

  defp next_month(year, 12), do: {year + 1, 1}
  defp next_month(year, month), do: {year, month + 1}

  defp month_name(1), do: "January"
  defp month_name(2), do: "February"
  defp month_name(3), do: "March"
  defp month_name(4), do: "April"
  defp month_name(5), do: "May"
  defp month_name(6), do: "June"
  defp month_name(7), do: "July"
  defp month_name(8), do: "August"
  defp month_name(9), do: "September"
  defp month_name(10), do: "October"
  defp month_name(11), do: "November"
  defp month_name(12), do: "December"
end
