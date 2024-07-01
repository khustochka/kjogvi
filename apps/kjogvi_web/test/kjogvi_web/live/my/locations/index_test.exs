defmodule KjogviWeb.Live.My.Locations.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "renders with no locations", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert index_live
           |> element("h1", "Locations")
           |> render()
  end

  test "renders with locations present", %{conn: conn} do
    insert(:location)

    {:ok, _index_live, html} = live(conn, ~p"/my/locations")

    assert html =~ "Winnipeg"
  end
end
