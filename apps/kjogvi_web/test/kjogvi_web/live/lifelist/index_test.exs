defmodule KjogviWeb.Live.Lifelist.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  def get_number_of_species(html) do
    {:ok, doc} = Floki.parse_document(html)

    Floki.find(doc, "#lifers tbody tr")
    |> length()
  end

  test "renders with no observations", %{conn: conn} do
    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert get_number_of_species(html) == 0
  end

  test "renders with species observation", %{conn: conn} do
    taxon = Ornitho.Factory.insert(:taxon, category: "species")
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert get_number_of_species(html) == 1
  end

  test "renders with spuh observation", %{conn: conn} do
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert get_number_of_species(html) == 0
  end

  test "renders with subspecies observation", %{conn: conn} do
    book = Ornitho.Factory.insert(:book)
    species = Ornitho.Factory.insert(:taxon, book: book, category: "species")
    taxon = Ornitho.Factory.insert(:taxon, book: book, category: "issf", parent_species: species)
    insert(:observation, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, _index_live, html} = live(conn, ~p"/lifelist")
    assert get_number_of_species(html) == 1
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

  @tag :skip
  # See branch empty_lifelist_404
  test "empty year lifelist returns Not Found, but still renders", %{conn: conn} do
    conn = get(conn, "/lifelist/2022")
    resp = html_response(conn, 404)

    assert get_number_of_species(resp) == 0
  end

  test "empty full lifelist is indexed by robots", %{conn: conn} do
    conn = get(conn, "/lifelist")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Enum.empty?(Floki.find(html, "meta[name=robots]"))
  end

  test "non-empty year list is indexed by robots", %{conn: conn} do
    species = Ornitho.Factory.insert(:taxon, category: "species")
    card = insert(:card, observ_date: ~D[2023-06-07])
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(species))
    conn = get(conn, "/lifelist/2023")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Enum.empty?(Floki.find(html, "meta[name=robots]"))
  end

  test "empty year list is not indexed by robots", %{conn: conn} do
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

  test "lifelist filtered by location", %{conn: conn} do
    ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
    usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
    brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

    taxon1 = Ornitho.Factory.insert(:taxon)
    card1 = insert(:card, location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    taxon2 = Ornitho.Factory.insert(:taxon)
    card2 = insert(:card, location: usa)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    conn = get(conn, "/lifelist/ukraine")
    resp = html_response(conn, 200)

    assert get_number_of_species(resp) == 1
  end

  test "lifelist filtered by year and location", %{conn: conn} do
    ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
    usa = insert(:location, slug: "usa", name_en: "United States", location_type: "country")
    brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

    taxon1 = Ornitho.Factory.insert(:taxon)
    card1 = insert(:card, observ_date: ~D"2022-11-18", location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    taxon2 = Ornitho.Factory.insert(:taxon)
    card2 = insert(:card, observ_date: ~D"2023-07-16", location: brovary)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))
    taxon3 = Ornitho.Factory.insert(:taxon)
    card2 = insert(:card, observ_date: ~D"2022-07-16", location: usa)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

    conn = get(conn, "/lifelist/2022/ukraine")
    resp = html_response(conn, 200)

    assert get_number_of_species(resp) == 1
  end

  test "lifelist with valid year and invalid location", %{conn: conn} do
    assert_error_sent :not_found, fn ->
      get(conn, "/lifelist/2022/testtest")
    end
  end

  test "correct links for guest user", %{conn: conn} do
    ukraine = insert(:location, slug: "ukraine", name_en: "Ukraine", location_type: "country")
    brovary = insert(:location, slug: "brovary", name_en: "Brovary", ancestry: [ukraine.id])

    taxon1 = Ornitho.Factory.insert(:taxon)
    card1 = insert(:card, observ_date: ~D"2022-11-18", location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    taxon2 = Ornitho.Factory.insert(:taxon)
    card2 = insert(:card, observ_date: ~D"2023-07-16", location: brovary)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    conn = get(conn, "/lifelist")
    resp = html_response(conn, 200)

    {:ok, doc} = Floki.parse_document(resp)
    links = Floki.find(doc, "li a") |> Enum.flat_map(&Floki.attribute(&1, "href"))

    assert ~p"/lifelist/2022" in links
    assert ~p"/lifelist/2023" in links
  end
end
