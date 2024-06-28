defmodule KjogviWeb.Live.Card.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders with no observations", %{conn: conn, user: user} do
    card = insert(:card, user: user)

    {:ok, _show_live, html} = live(conn, ~p"/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
    assert html =~ "This card has no observations."
  end

  test "renders with observations present", %{conn: conn, user: user} do
    card = insert(:card, user: user)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _show_live, html} = live(conn, ~p"/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
  end

  test "does not render for wrong user", %{conn: conn} do
    card = insert(:card, user: user_fixture())
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/cards/#{card.id}")
    end
  end
end
