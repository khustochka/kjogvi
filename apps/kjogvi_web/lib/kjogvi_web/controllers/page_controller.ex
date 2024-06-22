defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  @top_lifelist_num 5
  @default_countries [{"Canada", "canada"}, {"Ukraine", "ukraine"}]

  require Integer
  alias Kjogvi.Birding

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    primary_lists = [
      {"Last 5 lifers", ~p"/lifelist", Birding.Lifelist.top(@top_lifelist_num)},
      {"2024 list", ~p"/lifelist/2024", Birding.Lifelist.top(@top_lifelist_num, year: 2024)}
    ]

    country_lists =
      @default_countries
      |> Enum.reduce([], fn {name, slug}, acc ->
        loc = Kjogvi.Geo.location_by_slug(slug)

        if loc do
          acc ++
            [
              {"#{name} list", ~p"/lifelist/#{slug}",
               Birding.Lifelist.top(@top_lifelist_num, location: loc)}
            ]
        else
          acc
        end
      end)

    grouped_lists =
      (primary_lists ++ country_lists)
      |> pad_list({nil, nil, nil})
      |> Enum.chunk_every(2)

    conn
    |> assign(:grouped_lists, grouped_lists)
    |> render(:home)
  end

  defp pad_list(list, pad) do
    if Integer.is_odd(length(list)) do
      list ++ [pad]
    else
      list
    end
  end
end
