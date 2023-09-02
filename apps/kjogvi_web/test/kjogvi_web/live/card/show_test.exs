defmodule KjogviWeb.CardLive.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders with no observations", %{conn: conn} do
    card = insert(:card)

    conn = get(conn, ~p"/cards/#{card.id}")

    resp = html_response(conn, 200)
    assert resp =~ "Card ##{card.id}"
  end

  test "live renders with no observations", %{conn: conn} do
    card = insert(:card)

    {:ok, _show_live, html} = live(conn, ~p"/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
  end

  test "renders with observations present", %{conn: conn} do
    card = insert(:card)
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _show_live, html} = live(conn, ~p"/cards/#{card.id}")

    assert html =~ "Card ##{card.id}"
  end
end
