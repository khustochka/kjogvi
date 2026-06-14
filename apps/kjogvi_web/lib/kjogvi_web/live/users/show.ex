defmodule KjogviWeb.Live.Users.Show do
  @moduledoc """
  Public profile page for a single user: a birding diary with top lifelists and
  recent logbook additions, scoped to the viewed user.
  """

  use KjogviWeb, :live_view

  import KjogviWeb.Partials
  import KjogviWeb.LogbookComponents

  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Birding.Logbook
  alias KjogviWeb.Live

  @top_lifelist_num 5
  @default_countries ["canada", "ukraine"]

  @impl true
  def mount(_params, _session, %{assigns: assigns} = socket) do
    lifelist_scope = Lifelist.Scope.from_scope(assigns.current_scope)

    primary_lists = [
      {
        "Last #{@top_lifelist_num} lifers",
        Lifelist.top(lifelist_scope, @top_lifelist_num)
      },
      {
        Live.Lifelist.Presenter.title(year: 2026),
        Lifelist.top(lifelist_scope, @top_lifelist_num, year: 2026)
      }
    ]

    country_lists =
      @default_countries
      |> Enum.reduce([], fn slug, acc ->
        case Kjogvi.Geo.location_by_slug(slug) do
          nil ->
            acc

          loc ->
            acc ++
              [
                {
                  Live.Lifelist.Presenter.title(location: loc),
                  Lifelist.top(lifelist_scope, @top_lifelist_num, location: loc)
                }
              ]
        end
      end)

    logbook_entries = Logbook.recent_entries(lifelist_scope)

    {:ok,
     socket
     |> assign(:page_title, "Birding home")
     |> assign(:lists, primary_lists ++ country_lists)
     |> assign(:logbook_entries, logbook_entries)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.h1>
      Birding diary
    </.h1>

    <div class="md:grid md:grid-cols-2 md:gap-x-14 md:gap-y-8">
      <.top_n_list
        :for={{header, lifelist} <- @lists}
        list={lifelist.list}
        total={lifelist.total}
        href={lifelist_path(@current_scope, lifelist.filter)}
        class="mb-8 md:mb-0"
      >
        <:header>{header}</:header>
      </.top_n_list>
    </div>

    <div :if={@logbook_entries != []}>
      <.h2 class="mt-12">Recent additions</.h2>
      <.logbook logbook_entries={@logbook_entries} current_scope={@current_scope} />
    </div>
    """
  end
end
