defmodule KjogviWeb.Live.Admin.Ebird.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    %{conn: login_user(conn, admin_fixture())}
  end

  test "returns 404 for a non-admin user", %{conn: _conn} do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/ebird")

    assert response(conn, 404)
  end

  test "renders the heading and the count of eBird countries", %{conn: conn} do
    insert(:ebird_location, code: "AD")
    insert(:ebird_location, code: "CZ")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "h1", "eBird Locations")
    assert has_element?(view, "#ebird-countries-count", "2")
  end

  test "shows the total count of all eBird locations, delimited", %{conn: conn} do
    insert(:ebird_location, code: "AD")
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-countries-count", "1")
    assert has_element?(view, "#ebird-locations-count", "3")
  end

  test "shows each country with its status and subdivision counts", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location_id: sub1.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-AD", "Andorra")
    assert has_element?(view, "#ebird-country-AD", "mixed")
    assert has_element?(view, "#ebird-country-AD", "1/2 subdivisions linked")
  end

  test "marks countries that have subdivision2 regions with import progress", %{conn: conn} do
    country = insert(:country, iso_code: "US")
    insert(:ebird_location, code: "US", name: "United States", location_id: country.id)
    insert(:ebird_location, code: "AD", name: "Andorra")

    imported = insert(:location, country: country, location_type: :subdivision2)
    insert(:ebird_subdivision2, subnational1_code: "US-CA", location_id: imported.id)
    insert(:ebird_subdivision2, subnational1_code: "US-CA")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-US", "1/2 sub2 imported")
    refute has_element?(view, "#ebird-country-AD", "sub2 imported")
  end

  test "shows the linked common location for a linked country, nothing for an unlinked one",
       %{conn: conn} do
    linked = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: linked.id)
    insert(:ebird_location, code: "CZ", name: "Czechia")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert view
           |> element("#ebird-country-AD a[href='/admin/locations/#{linked.slug}']", "Andorra")
           |> has_element?()

    refute has_element?(view, "#ebird-country-CZ a[href^='/admin/locations/']")
  end

  test "shows mismatch-shape statuses for triage", %{conn: conn} do
    # name_candidate: same names, different codes (the Poland case).
    pl = insert(:country, iso_code: "PL")
    insert(:subdivision1, iso_code: "PL-DS", name_en: "Lower Silesia", country: pl)
    insert(:ebird_location, code: "PL", name: "Poland")
    insert(:ebird_subdivision1, country_code: "PL", code: "PL-72", name: "Lower Silesia")

    # iso_extra: eBird codes are a subset of the ISO codes.
    pt = insert(:country, iso_code: "PT")
    insert(:subdivision1, iso_code: "PT-01", country: pt)
    insert(:subdivision1, iso_code: "PT-02", country: pt)
    insert(:ebird_location, code: "PT", name: "Portugal")
    insert(:ebird_subdivision1, country_code: "PT", code: "PT-01")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-PL", "name-pass candidate")
    assert has_element?(view, "#ebird-country-PT", "ISO extra")
  end

  test "links each country to its workbench", %{conn: conn} do
    insert(:ebird_location, code: "AD", name: "Andorra")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert view
           |> element("#ebird-country-AD a", "Andorra")
           |> render() =~ ~p"/admin/ebird/AD"
  end

  test "filters countries by status", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    insert(:ebird_location, code: "CZ", name: "Czechia")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-AD")
    assert has_element?(view, "#ebird-country-CZ")

    view
    |> element("#ebird-status-filter a", "eBird only")
    |> render_click()

    refute has_element?(view, "#ebird-country-AD")
    assert has_element?(view, "#ebird-country-CZ")
  end

  test "the work filter keeps only countries with subdivisions still to link", %{conn: conn} do
    # Fully linked: country and its one subdivision both linked.
    done = insert(:country, iso_code: "AD", name_en: "Andorra")
    sub1 = insert(:subdivision1, iso_code: "AD-02", country: done)
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: done.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location_id: sub1.id)

    # A perfect-match country the bulk pass has not linked yet: reads matched,
    # but still has rows to link, so it belongs to the work queue.
    todo = insert(:country, iso_code: "PT", name_en: "Portugal")
    insert(:subdivision1, iso_code: "PT-01", country: todo)
    insert(:ebird_location, code: "PT", name: "Portugal")
    insert(:ebird_subdivision1, country_code: "PT", code: "PT-01")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-AD")
    assert has_element?(view, "#ebird-country-PT")

    view
    |> element("#ebird-work-filter a", "Not fully linked")
    |> render_click()

    refute has_element?(view, "#ebird-country-AD")
    assert has_element?(view, "#ebird-country-PT")
  end

  test "the work and status filters compose", %{conn: conn} do
    # eBird-only, unlinked — incomplete, status ebird_only.
    insert(:ebird_location, code: "XK", name: "Kosovo")

    # Perfect-match, unlinked — incomplete, status matched.
    pt = insert(:country, iso_code: "PT", name_en: "Portugal")
    insert(:subdivision1, iso_code: "PT-01", country: pt)
    insert(:ebird_location, code: "PT", name: "Portugal")
    insert(:ebird_subdivision1, country_code: "PT", code: "PT-01")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird?work=incomplete&status=ebird_only")

    assert has_element?(view, "#ebird-country-XK")
    refute has_element?(view, "#ebird-country-PT")

    # The status chips stay scoped to the work filter (the href carries it).
    assert view
           |> element("#ebird-status-filter a", "matched")
           |> render() =~ "work=incomplete"
  end

  test "the subdivision2 filter keeps only countries with sub2 regions", %{conn: conn} do
    insert(:ebird_location, code: "US", name: "United States")
    insert(:ebird_subdivision2, subnational1_code: "US-CA")
    insert(:ebird_location, code: "AD", name: "Andorra")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-US")
    assert has_element?(view, "#ebird-country-AD")

    view
    |> element("#ebird-sub2-filter a", "With subdivision2 (1)")
    |> render_click()

    assert has_element?(view, "#ebird-country-US")
    refute has_element?(view, "#ebird-country-AD")

    # The other chip rows carry the sub2 filter along.
    assert view
           |> element("#ebird-work-filter a", "Not fully linked")
           |> render() =~ "sub2=present"
  end

  test "shows an empty state when the dataset is empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "p", "No eBird locations yet")
  end

  test "the bulk match button links clean countries and refreshes statuses", %{conn: conn} do
    clean = insert(:country, iso_code: "AD", name_en: "Andorra")
    clean_sub1 = insert(:subdivision1, iso_code: "AD-02", country: clean)
    ebird_clean = insert(:ebird_location, code: "AD", name: "Andorra")
    ebird_clean_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    refute has_element?(view, "#ebird-country-AD a[href='/admin/locations/#{clean.slug}']")

    render_click(element(view, "#run-bulk-match-button"))
    render_async(view)

    assert has_element?(view, "#ebird-country-AD a[href='/admin/locations/#{clean.slug}']")
    assert has_element?(view, "#ebird-country-AD", "1/1 subdivisions linked")

    assert Kjogvi.Repo.reload!(ebird_clean).location_id == clean.id
    assert Kjogvi.Repo.reload!(ebird_clean_sub1).location_id == clean_sub1.id
  end

  test "highlights fully-linked countries with a green background", %{conn: conn} do
    done = insert(:country, iso_code: "AD", name_en: "Andorra")
    sub1 = insert(:subdivision1, iso_code: "AD-02", country: done)
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: done.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location_id: sub1.id)

    insert(:ebird_location, code: "CZ", name: "Czechia")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-AD.bg-forest-50")
    refute has_element?(view, "#ebird-country-CZ.bg-forest-50")
  end

  test "the bulk match button is hidden when the dataset is empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    refute has_element?(view, "#run-bulk-match-button")
  end
end
