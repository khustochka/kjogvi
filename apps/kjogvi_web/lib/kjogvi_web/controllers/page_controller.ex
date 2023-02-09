defmodule KjogviWeb.PageController do
  use KjogviWeb, :controller

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.
    # render(conn, :home, layout: false)
    render(conn, :home)
  end
end
