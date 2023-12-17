defmodule KjogviWeb.Live.Lifelist.IndexTest do
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

  test "unacceptable year segment - string", %{conn: conn} do
    assert_raise KjogviWeb.Exception.BadParams, fn ->
      get(conn, "/lifelist/abc")
    end
  end

  test "unacceptable year segment - number", %{conn: conn} do
    assert_raise KjogviWeb.Exception.BadParams, fn ->
      get(conn, "/lifelist/20233")
    end
  end

  @tag :skip
  test "empty year lifelist returns Not Found, but still renders", %{conn: conn} do
    conn = get(conn, "/lifelist/2022")
    resp = html_response(conn, 404)

    assert resp =~ "Total of 0 species."
  end

  test "empty full lifelist is indexed", %{conn: conn} do
    conn = get(conn, "/lifelist")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Enum.empty?(Floki.find(html, "meta[name=robots]"))
  end

  test "non-empty year list is indexed", %{conn: conn} do
    species = Ornitho.Factory.insert(:taxon, category: "species")
    card = insert(:card, observ_date: ~D[2023-06-07])
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(species))
    conn = get(conn, "/lifelist/2023")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Enum.empty?(Floki.find(html, "meta[name=robots]"))
  end

  test "empty year list is not indexed", %{conn: conn} do
    conn = get(conn, "/lifelist/2022")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Floki.attribute(html, "meta[name=robots]", "content") == ["noindex"]
  end

  @tag skip: "False negative test (passing when it should fail)"
  test "noindex disappears when navigating from empty to non-empty year list", %{conn: conn} do
    species = Ornitho.Factory.insert(:taxon, category: "species")
    card = insert(:card, observ_date: ~D[2023-06-07])
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(species))

    {:ok, index_live, doc} = live(conn, ~p"/lifelist/2022")
    {:ok, html} = Floki.parse_document(doc)

    assert Floki.attribute(html, "meta[name=robots]", "content") == ["noindex"]

    doc2 = index_live |> element("a", "2023") |> render_click()

    {:ok, html2} = Floki.parse_document(doc2)

    assert Enum.empty?(Floki.find(html2, "meta[name=robots]"))
  end
end
