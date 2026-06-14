defmodule KjogviWeb.HomeController do
  use KjogviWeb, :controller

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    conn
    |> assign(:page_title, "Birders")
    |> assign(:users, Kjogvi.Accounts.list_users_by_lifelist_size(limit: 10))
    |> render(:home)
  end
end
