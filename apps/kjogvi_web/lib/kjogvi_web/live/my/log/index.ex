defmodule KjogviWeb.Live.My.Log.Index do
  @moduledoc false

  use KjogviWeb, :live_view

  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist

  import KjogviWeb.LogComponents

  @default_opts [limit: 366, cutoff_days: 366]

  @impl true
  def mount(_params, _session, %{assigns: assigns} = socket) do
    lifelist_scope = Lifelist.Scope.from_scope(assigns.current_scope)
    all_years = Lifelist.years(lifelist_scope)

    {
      :ok,
      socket
      |> assign(:lifelist_scope, lifelist_scope)
      |> assign(:all_years, all_years)
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

    log_entries = Log.recent_entries(assigns.lifelist_scope, opts)

    {
      :noreply,
      socket
      |> assign(:page_title, "Birding log#{if year, do: " – #{year}"}")
      |> assign(:year, year)
      |> assign(:log_entries, log_entries)
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      {@page_title}
    </.h1>

    <ul class="my-6 flex flex-wrap gap-1.5">
      <.year_filter_entry
        text="Latest"
        url={~p"/my/log"}
        selected={is_nil(@year)}
      />

      <%= for year <- @all_years do %>
        <.year_filter_entry
          text={to_string(year)}
          url={~p"/my/log?year=#{year}"}
          selected={@year == year}
        />
      <% end %>
    </ul>

    <.log log_entries={@log_entries} current_scope={@current_scope} />
    """
  end

  defp year_filter_entry(%{selected: true} = assigns) do
    ~H"""
    <li>
      <span class="block text-center w-16 py-1 text-sm font-bold text-forest-800 bg-forest-100 border border-forest-300 rounded">
        {@text}
      </span>
    </li>
    """
  end

  defp year_filter_entry(assigns) do
    ~H"""
    <li>
      <.link
        patch={@url}
        class="block text-center w-16 py-1 text-sm text-forest-600 bg-white border border-stone-300 rounded hover:bg-forest-50 no-underline"
      >
        {@text}
      </.link>
    </li>
    """
  end
end
