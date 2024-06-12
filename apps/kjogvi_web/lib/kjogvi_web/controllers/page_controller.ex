defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  @top_lifelist_num 5

  alias Kjogvi.Birding

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    Birding.Lifelist.top(@top_lifelist_num)
    |> then(fn result ->
      conn
      |> assign(:lifelist, result.lifelist)
      |> assign(:total, result.total)
      |> render(:home)
    end)
  end
end
