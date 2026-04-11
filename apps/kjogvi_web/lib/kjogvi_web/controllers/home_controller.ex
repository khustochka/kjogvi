defmodule KjogviWeb.HomeController do
  use KjogviWeb, :controller

  @top_lifelist_num 5
  @default_countries ["canada", "ukraine"]

  alias Kjogvi.Birding
  alias Kjogvi.Birding.Log
  alias Kjogvi.Birding.Lifelist
  alias KjogviWeb.Live

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(%{assigns: assigns} = conn, _params) do
    lifelist_scope = Lifelist.Scope.from_scope(assigns.current_scope)

    primary_lists = [
      {
        "Last 5 lifers",
        Birding.Lifelist.top(lifelist_scope, @top_lifelist_num)
      },
      {
        Live.Lifelist.Presenter.title(year: 2025),
        Birding.Lifelist.top(lifelist_scope, @top_lifelist_num, year: 2026)
      }
    ]

    country_lists =
      @default_countries
      |> Enum.reduce([], fn slug, acc ->
        loc = Kjogvi.Geo.location_by_slug(slug)

        if loc do
          acc ++
            [
              {
                Live.Lifelist.Presenter.title(location: loc),
                Birding.Lifelist.top(lifelist_scope, @top_lifelist_num, location: loc)
              }
            ]
        else
          acc
        end
      end)

    log_entries = Log.recent_entries(lifelist_scope)

    conn
    |> assign(:page_title, "Birding highlights")
    |> assign(:lists, primary_lists ++ country_lists)
    |> assign(:log_entries, log_entries)
    |> render(:home)
  end
end
