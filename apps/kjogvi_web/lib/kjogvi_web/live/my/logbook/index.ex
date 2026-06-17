defmodule KjogviWeb.Live.My.Logbook.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Birding.Logbook
  alias Kjogvi.Birding.Lifelist

  import KjogviWeb.LogbookComponents

  @default_opts [limit: 366, cutoff_days: 366]

  @impl true
  def mount(_params, _session, %{assigns: assigns} = socket) do
    lifelist_scope = Lifelist.Scope.from_scope(assigns.current_scope)
    all_years = Lifelist.years(lifelist_scope)
    logbook_enabled? = Logbook.any_enabled?(lifelist_scope)

    {
      :ok,
      socket
      |> assign(:lifelist_scope, lifelist_scope)
      |> assign(:all_years, all_years)
      |> assign(:logbook_enabled?, logbook_enabled?)
    }
  end

  @impl true
  def handle_params(params, _url, %{assigns: assigns} = socket) do
    year_str = params["year"]

    {year, opts} =
      if year_str && year_str =~ ~r/\A\d+\Z/ do
        String.to_integer(year_str)
        |> then(fn year -> {year, [year: year]} end)
      else
        {nil, @default_opts}
      end

    logbook_entries = Logbook.recent_entries(assigns.lifelist_scope, opts)

    {
      :noreply,
      socket
      |> assign(:page_title, "Birding logbook#{if year, do: " – #{year}"}")
      |> assign(:year, year)
      |> assign(:logbook_entries, logbook_entries)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      {@page_title}
    </.h1>

    <div class="mt-2 mb-4 text-sm">
      <.link
        navigate={~p"/my/settings/preferences#logbook-settings"}
        class="text-forest-700 underline hover:text-forest-900"
      >
        Logbook settings
      </.link>
    </div>

    <ul class="my-6 flex flex-wrap gap-1.5" aria-label="Year">
      <.inline_filter_pill href={~p"/my/logbook"} selected={is_nil(@year)}>
        Latest
      </.inline_filter_pill>

      <.inline_filter_pill
        :for={year <- @all_years}
        href={~p"/my/logbook?year=#{year}"}
        selected={@year == year}
      >
        {year}
      </.inline_filter_pill>
    </ul>

    <div
      :if={@logbook_entries == [] and not @logbook_enabled?}
      id="logbook-empty-no-settings"
      class="my-6 p-4 rounded border border-amber-300 bg-amber-50 text-sm text-stone-700"
    >
      No lists are selected for the logbook.
      <.link
        navigate={~p"/my/settings/preferences#logbook-settings"}
        class="text-forest-700 underline hover:text-forest-900"
      >
        Enable some in Settings
      </.link>
      to start seeing recent additions.
    </div>

    <.logbook logbook_entries={@logbook_entries} current_scope={@current_scope} />
    """
  end
end
