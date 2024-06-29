defmodule KjogviWeb.HomeController do
  use KjogviWeb, :controller

  @top_lifelist_num 5
  @default_countries ["canada", "ukraine"]

  require Integer
  alias Kjogvi.Birding
  alias KjogviWeb.Live
  alias Kjogvi.Settings

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    user = Settings.main_user()

    primary_lists = [
      {
        "Last 5 lifers",
        lifelist_path(),
        Birding.Lifelist.top(user, @top_lifelist_num)
      },
      {
        Live.Lifelist.Presenter.title(year: 2024),
        lifelist_path(year: 2024),
        Birding.Lifelist.top(user, @top_lifelist_num, year: 2024)
      }
    ]

    country_lists =
      @default_countries
      |> Enum.reduce([], fn slug, acc ->
        loc = Kjogvi.Geo.location_by_slug(nil, slug)

        if loc do
          acc ++
            [
              {
                Live.Lifelist.Presenter.title(location: loc),
                lifelist_path(location: loc),
                Birding.Lifelist.top(user, @top_lifelist_num, location: loc)
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
