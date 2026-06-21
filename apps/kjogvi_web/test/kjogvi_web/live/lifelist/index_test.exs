defmodule KjogviWeb.Live.Lifelist.IndexTest do
  alias Kjogvi.Factory
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup do
    %{user: Kjogvi.AccountsFixtures.user_fixture()}
  end

  def get_number_of_species(html) do
    {:ok, doc} = Floki.parse_document(html)

    Floki.find(doc, "#lifelist-table li[id^=lifer-]")
    |> length()
  end

  test "renders with no observations", %{conn: conn, user: user} do
    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist")
    assert get_number_of_species(html) == 0
  end

  test "renders with species observation", %{conn: conn, user: user} do
    {taxon, _} = Factory.create_species_taxon_with_page()

    insert(:observation,
      taxon_key: Ornitho.Schema.Taxon.key(taxon),
      card: insert(:card, user: user)
    )

    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist")
    assert get_number_of_species(html) == 1
  end

  test "public lifelist hides a private ancestor's name in the location column",
       %{conn: conn, user: user} do
    {taxon, _} = Factory.create_species_taxon_with_page()

    country = insert(:country, name_en: "Canada")

    # A private subdivision1 between the public country and a public city.
    secret =
      insert(:location,
        name_en: "SecretRegion",
        location_type: "subdivision1",
        is_private: true,
        country: country
      )

    city =
      insert(:location,
        name_en: "Winnipeg",
        location_type: "city",
        country: country,
        subdivision1_id: secret.id
      )

    insert(:observation,
      taxon_key: Ornitho.Schema.Taxon.key(taxon),
      card: insert(:card, user: user, location: city)
    )

    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    assert html =~ "Winnipeg"
    assert html =~ "Canada"
    refute html =~ "SecretRegion"
  end

  test "renders with spuh observation", %{conn: conn, user: user} do
    taxon = Ornitho.Factory.insert(:taxon, category: "spuh")

    insert(:observation,
      taxon_key: Ornitho.Schema.Taxon.key(taxon),
      card: insert(:card, user: user)
    )

    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist")
    assert get_number_of_species(html) == 0
  end

  test "renders with subspecies observation", %{conn: conn, user: user} do
    {taxon, _} = Factory.create_subspecies_taxon_with_page()

    insert(:observation,
      taxon_key: Ornitho.Schema.Taxon.key(taxon),
      card: insert(:card, user: user)
    )

    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist")
    assert get_number_of_species(html) == 1
  end

  test "filters by year", %{conn: conn, user: user} do
    {species1, _} = Factory.create_species_taxon_with_page()
    {species2, _} = Factory.create_species_taxon_with_page()

    card1 = insert(:card, user: user, observ_date: ~D[2023-06-07])
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(species1))
    card2 = insert(:card, user: user, observ_date: ~D[2022-04-03])
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(species2))

    {:ok, _index_live, html} = live(conn, ~p"/users/#{user.nickname}/lifelist/2022")

    assert html =~ species2.name_en
    assert not (html =~ species1.name_en)
  end

  @tag skip: "Not implemented yet"
  # See branch empty_lifelist_404
  test "empty year lifelist returns Not Found, but still renders", %{conn: conn, user: user} do
    conn = get(conn, "/users/#{user.nickname}/lifelist/2022")
    resp = html_response(conn, 404)

    assert get_number_of_species(resp) == 0
  end

  test "non-empty year list is indexed by robots", %{conn: conn, user: user} do
    {species, _} = Factory.create_species_taxon_with_page()

    insert(:observation,
      taxon_key: Ornitho.Schema.Taxon.key(species),
      card: insert(:card, user: user, observ_date: ~D[2023-06-07])
    )

    conn = get(conn, "/users/#{user.nickname}/lifelist/2023")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert html |> Floki.find("meta[name=robots]") |> Enum.empty?()
  end

  test "empty year list is not indexed by robots", %{conn: conn, user: user} do
    conn = get(conn, "/users/#{user.nickname}/lifelist/2022")
    resp = html_response(conn, 200)

    {:ok, html} = Floki.parse_document(resp)

    assert Floki.attribute(html, "meta[name=robots]", "content") == ["noindex"]
  end

  test "lifelist filtered by location", %{conn: conn, user: user} do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    usa =
      insert(:country,
        slug: "usa",
        name_en: "United States",
        public_index: 2
      )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine
      )

    {taxon1, _} = Factory.create_species_taxon_with_page()
    card1 = insert(:card, user: user, location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    {taxon2, _} = Factory.create_species_taxon_with_page()
    card2 = insert(:card, user: user, location: usa)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    conn = get(conn, "/users/#{user.nickname}/lifelist/ukraine")
    resp = html_response(conn, 200)

    assert get_number_of_species(resp) == 1
  end

  test "lifelist filtered by year and location", %{conn: conn, user: user} do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    usa =
      insert(:country,
        slug: "usa",
        name_en: "United States",
        public_index: 2
      )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine
      )

    {taxon1, _} = Factory.create_species_taxon_with_page()
    card1 = insert(:card, user: user, observ_date: ~D"2022-11-18", location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    {taxon2, _} = Factory.create_species_taxon_with_page()
    card2 = insert(:card, user: user, observ_date: ~D"2023-07-16", location: brovary)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))
    {taxon3, _} = Factory.create_species_taxon_with_page()
    card2 = insert(:card, user: user, observ_date: ~D"2022-07-16", location: usa)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

    conn = get(conn, "/users/#{user.nickname}/lifelist/2022/ukraine")
    resp = html_response(conn, 200)

    assert get_number_of_species(resp) == 1
  end

  test "location card shows breadcrumb with ancestors when filtered", %{conn: conn, user: user} do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    oblast =
      insert(:location,
        slug: "kyiv-oblast",
        name_en: "Kyiv Oblast",
        location_type: "subdivision1",
        country: ukraine,
        public_index: 2
      )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine,
        subdivision1_id: oblast.id
      )

    {taxon, _} = Factory.create_species_taxon_with_page()
    card = insert(:card, user: user, location: brovary)
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist/kyiv-oblast")

    assert has_element?(view, "#lifelist-location-selector")
    # Breadcrumb shows World and Ukraine (the country ancestor) as links
    assert has_element?(view, "#lifelist-location-selector a", "World")
    assert has_element?(view, "#lifelist-location-selector a", "Ukraine")
    # Kyiv Oblast is the selected pill in the siblings list
    assert has_element?(view, "#lifelist-location-selector span.font-bold", "Kyiv Oblast")
  end

  test "location card shows World as bold when no location filter", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    assert has_element?(view, "#lifelist-location-selector span.font-bold", "World")
  end

  test "location selector only lists locations with observations", %{conn: conn, user: user} do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    # Lifelist location with no observations at all — must not appear.
    insert(:country,
      slug: "usa",
      name_en: "United States",
      public_index: 2
    )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine
      )

    {taxon, _} = Factory.create_species_taxon_with_page()
    card = insert(:card, user: user, location: brovary)
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    assert has_element?(view, "#lifelist-location-selector a", "Ukraine")
    refute has_element?(view, "#lifelist-location-selector a", "United States")
  end

  test "location pill is present but inactive when outside the current filter", %{
    conn: conn,
    user: user
  } do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    usa =
      insert(:country,
        slug: "usa",
        name_en: "United States",
        public_index: 2
      )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine
      )

    # Ukraine has a 2022 observation; USA only has a 2023 one.
    {taxon1, _} = Factory.create_species_taxon_with_page()
    card1 = insert(:card, user: user, observ_date: ~D"2022-05-01", location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    {taxon2, _} = Factory.create_species_taxon_with_page()
    card2 = insert(:card, user: user, observ_date: ~D"2023-05-01", location: usa)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    # Filtering by 2022: USA still renders (has observations overall) but is
    # inactive, so it shows as a non-link span rather than a clickable link.
    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist/2022")

    assert has_element?(view, "#lifelist-location-selector a", "Ukraine")
    refute has_element?(view, "#lifelist-location-selector a", "United States")
    assert has_element?(view, "#lifelist-location-selector span", "United States")
  end

  test "lifelist with valid year and invalid location", %{conn: conn, user: user} do
    assert_error_sent :bad_request, fn ->
      get(conn, "/users/#{user.nickname}/lifelist/2022/testtest")
    end
  end

  test "each row has an anchor id matching its rank", %{conn: conn, user: user} do
    {taxon1, _} = Factory.create_species_taxon_with_page()
    {taxon2, _} = Factory.create_species_taxon_with_page()

    card1 = insert(:card, user: user, observ_date: ~D"2023-01-01")
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    card2 = insert(:card, user: user, observ_date: ~D"2023-06-01")
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    # 2 species total; most recent is rank 2, oldest is rank 1
    assert has_element?(view, "#lifer-2")
    assert has_element?(view, "#lifer-1")
  end

  test "sorting taxonomically reorders species", %{conn: conn, user: user} do
    {taxon1, _} = Factory.create_species_taxon_with_page()
    {taxon2, _} = Factory.create_species_taxon_with_page()

    # taxon1 created first ⇒ lower sort_order; observed earlier
    card1 = insert(:card, user: user, observ_date: ~D"2020-01-01")
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    card2 = insert(:card, user: user, observ_date: ~D"2024-01-01")
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    pos = fn html, taxon ->
      :binary.match(html, taxon.name_en) |> elem(0)
    end

    {:ok, _view, taxonomy_html} =
      live(conn, ~p"/users/#{user.nickname}/lifelist?sort=taxonomy")

    # Taxonomic (sort_order asc): taxon1 first
    assert pos.(taxonomy_html, taxon1) < pos.(taxonomy_html, taxon2)

    {:ok, _view, date_html} = live(conn, ~p"/users/#{user.nickname}/lifelist")
    # Date desc: taxon2 (more recent) first
    assert pos.(date_html, taxon2) < pos.(date_html, taxon1)
  end

  test "date sort groups lifers by year of first encounter", %{conn: conn, user: user} do
    {taxon1, _} = Factory.create_species_taxon_with_page()
    {taxon2, _} = Factory.create_species_taxon_with_page()
    {taxon3, _} = Factory.create_species_taxon_with_page()

    card1 = insert(:card, user: user, observ_date: ~D"2021-05-01")
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    card2 = insert(:card, user: user, observ_date: ~D"2023-04-01")
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))
    card3 = insert(:card, user: user, observ_date: ~D"2023-09-01")
    insert(:observation, card: card3, taxon_key: Ornitho.Schema.Taxon.key(taxon3))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    assert has_element?(view, "#first-record-2023")
    assert has_element?(view, "#first-record-2021")
    assert has_element?(view, "#lifelist-table h3", "First recorded in")
  end

  test "year header is omitted when filtered by year", %{conn: conn, user: user} do
    {taxon, _} = Factory.create_species_taxon_with_page()
    card = insert(:card, user: user, observ_date: ~D"2023-05-01")
    insert(:observation, card: card, taxon_key: Ornitho.Schema.Taxon.key(taxon))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist/2023")

    refute has_element?(view, "#first-record-2023")
    refute has_element?(view, "#lifelist-table h3", "First recorded in")
  end

  test "year header is omitted when sorting taxonomically", %{conn: conn, user: user} do
    {taxon1, _} = Factory.create_species_taxon_with_page()
    {taxon2, _} = Factory.create_species_taxon_with_page()

    card1 = insert(:card, user: user, observ_date: ~D"2021-05-01")
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    card2 = insert(:card, user: user, observ_date: ~D"2023-04-01")
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist?sort=taxonomy")

    refute has_element?(view, "#first-record-2023")
    refute has_element?(view, "#lifelist-table h3", "First recorded in")
  end

  test "sort selector links toggle between date and taxonomy", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/users/#{user.nickname}/lifelist")

    assert has_element?(view, "ul[aria-label=Sort] a", "Taxonomic")
    assert has_element?(view, "ul[aria-label=Sort] span", "By date")

    {:ok, view2, _html2} = live(conn, ~p"/users/#{user.nickname}/lifelist?sort=taxonomy")

    assert has_element?(view2, "ul[aria-label=Sort] span", "Taxonomic")
    assert has_element?(view2, "ul[aria-label=Sort] a", "By date")
  end

  test "correct links for guest user", %{conn: conn, user: user} do
    ukraine =
      insert(:country,
        slug: "ukraine",
        name_en: "Ukraine",
        public_index: 1
      )

    brovary =
      insert(:location,
        slug: "brovary",
        name_en: "Brovary",
        location_type: "city",
        country: ukraine
      )

    {taxon1, _} = Factory.create_species_taxon_with_page()
    card1 = insert(:card, user: user, observ_date: ~D"2022-11-18", location: brovary)
    insert(:observation, card: card1, taxon_key: Ornitho.Schema.Taxon.key(taxon1))
    {taxon2, _} = Factory.create_species_taxon_with_page()
    card2 = insert(:card, user: user, observ_date: ~D"2023-07-16", location: brovary)
    insert(:observation, card: card2, taxon_key: Ornitho.Schema.Taxon.key(taxon2))

    conn = get(conn, "/users/#{user.nickname}/lifelist")
    resp = html_response(conn, 200)

    {:ok, doc} = Floki.parse_document(resp)
    links = Floki.find(doc, "li a") |> Enum.flat_map(&Floki.attribute(&1, "href"))

    assert ~p"/users/#{user.nickname}/lifelist/2022" in links
    assert ~p"/users/#{user.nickname}/lifelist/2023" in links
  end

  describe "community lifelist" do
    test "aggregates species across all users", %{conn: conn, user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()

      {taxon1, _} = Factory.create_species_taxon_with_page()
      {taxon2, _} = Factory.create_species_taxon_with_page()

      insert(:observation,
        taxon_key: Ornitho.Schema.Taxon.key(taxon1),
        card: insert(:card, user: user)
      )

      insert(:observation,
        taxon_key: Ornitho.Schema.Taxon.key(taxon2),
        card: insert(:card, user: other_user)
      )

      {:ok, _index_live, html} = live(conn, ~p"/community/lifelist")

      assert get_number_of_species(html) == 2
      assert html =~ taxon1.name_en
      assert html =~ taxon2.name_en
    end

    test "filter links point back to the community URL space", %{conn: conn, user: user} do
      insert(:observation,
        taxon_key: Ornitho.Schema.Taxon.key(elem(Factory.create_species_taxon_with_page(), 0)),
        card: insert(:card, user: user, observ_date: ~D"2023-07-16")
      )

      conn = get(conn, ~p"/community/lifelist")
      resp = html_response(conn, 200)

      {:ok, doc} = Floki.parse_document(resp)
      links = Floki.find(doc, "li a") |> Enum.flat_map(&Floki.attribute(&1, "href"))

      assert ~p"/community/lifelist/2023" in links
    end
  end
end
