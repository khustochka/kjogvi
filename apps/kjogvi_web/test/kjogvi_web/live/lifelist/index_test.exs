defmodule KjogviWeb.LifelistLive.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders with no observations", %{conn: conn} do
    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert html =~ "Total of 0 species."
  end
end
