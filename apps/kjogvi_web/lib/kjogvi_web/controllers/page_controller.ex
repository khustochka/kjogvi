defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
