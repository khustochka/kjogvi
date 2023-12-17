defmodule KjogviWeb.Live.Location.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders with no locations", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/locations")

    assert index_live
           |> element("h1", "Locations")
           |> render()
  end

  test "renders with locations present", %{conn: conn} do
    insert(:location)

    {:ok, _index_live, html} = live(conn, ~p"/locations")

    assert html =~ "Winnipeg"
  end
end
