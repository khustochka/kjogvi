defmodule KjogviWeb.CardLive.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders with no cards", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/cards")

    assert index_live
           |> element("h1", "Cards")
           |> render()
  end
end
