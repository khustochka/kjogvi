defmodule KjogviWeb.SpeciesController do
  use KjogviWeb, :controller

  alias Kjogvi.Pages.Species

  @spec show(Plug.Conn.t(), any()) :: Plug.Conn.t()
  def show(conn, %{"slug" => slug} = _params) do
    conn
    |> assign(:species, Species.from_slug(slug))
    |> render(:show)
  end
end
