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
end
