defmodule KjogviWeb.LifelistLive.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders with no observations", %{conn: conn} do
    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert html =~ "Total of 0 species."
  end

  test "renders with species observation", %{conn: conn} do
    taxon = Ornitho.Factory.insert(:taxon, category: "species")
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert html =~ "Total of 1 species."
  end

  test "renders with spuh observation", %{conn: conn} do
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert html =~ "Total of 0 species."
  end

  test "renders with subspecies observation", %{conn: conn} do
    book = Ornitho.Factory.insert(:book)
    species = Ornitho.Factory.insert(:taxon, book: book, category: "species")
    taxon = Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert html =~ "Total of 1 species."
  end

  test "filters by year", %{conn: conn} do
    book = Ornitho.Factory.insert(:book)
    species1 = Ornitho.Factory.insert(:taxon, book: book, category: "species")
    species2 = Ornitho.Factory.insert(:taxon, book: book, category: "species")
    card1 = insert(:card, observ_date: ~D[2023-06-07])
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(species1))
    card2 = insert(:card, observ_date: ~D[2022-04-03])
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(species2))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist/2022")

    assert html =~ species2.name_en
    assert not (html =~ species1.name_en)
  end
end
