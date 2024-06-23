defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  @top_lifelist_num 5
  @default_countries [{"Canada", "canada"}, {"Ukraine", "ukraine"}]

  require Integer
  alias Kjogvi.Birding

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    primary_lists = [
      {"Last 5 lifers", lifelist_path(), Birding.Lifelist.top(@top_lifelist_num)},
      {"2024 list", lifelist_path(year: 2024),
       Birding.Lifelist.top(@top_lifelist_num, year: 2024)}
    ]

    country_lists =
      @default_countries
      |> Enum.reduce([], fn {name, slug}, acc ->
        loc = Kjogvi.Geo.location_by_slug(nil, slug)

        if loc do
          acc ++
            [
              {"#{name} list", lifelist_path(location: loc),
               Birding.Lifelist.top(@top_lifelist_num, location: loc)}
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
