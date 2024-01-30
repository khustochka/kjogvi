defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  @spec home(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def home(conn, _params) do
    render(conn, :home)
  end
end
