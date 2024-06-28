defmodule KjogviWeb.Live.Card.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders with no cards", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/cards")

    assert index_live
           |> element("h1", "Cards")
           |> render()
  end

  test "renders with cards present", %{conn: conn, user: user} do
    insert(:card, user: user)

    {:ok, _index_live, html} = live(conn, ~p"/cards")

    assert html =~ "Winnipeg"
  end

  test "pagination with multiple cards", %{conn: conn, user: user} do
    location = insert(:location)
    insert_list(51, :card, location: location, user: user)

    {:ok, _index_live, html} = live(conn, ~p"/cards")

    assert html =~ "/cards/page/2"
  end
end
