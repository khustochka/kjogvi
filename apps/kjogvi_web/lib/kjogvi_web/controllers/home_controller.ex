defmodule KjogviWeb.HomeController do
  use KjogviWeb, :controller

  @top_lifelist_num 5
  @default_countries ["canada", "ukraine"]

  # require Integer
  alias Kjogvi.Birding
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
        Birding.Lifelist.top(lifelist_scope, @top_lifelist_num, year: 2025)
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

    conn
    |> assign(:lists, primary_lists ++ country_lists)
    |> render(:home)
  end
end
