defmodule KjogviWeb.Live.Admin.Locations.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    %{conn: login_user(conn, admin_fixture())}
  end

  test "returns 404 for a non-admin user", %{conn: _conn} do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/locations")

    assert response(conn, 404)
  end

  test "renders the heading and the count of common locations", %{conn: conn} do
    country = insert(:country, name_en: "Canada")
    insert(:subdivision1, name_en: "Manitoba", country: country)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "h1", "Common Locations")
    assert has_element?(index_live, "#common-locations-count", "2")
  end

  test "shows a common country even when nothing hangs under it", %{conn: conn} do
    insert(:country, name_en: "Mongolia")

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "a", "Mongolia")
  end

  test "does not show personal locations or specials", %{conn: conn} do
    country = insert(:country, name_en: "Canada")
    insert(:location, name_en: "Their Patch", country: country, user_id: user_fixture().id)
    insert(:special, name_en: "Common Special")

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    refute has_element?(index_live, "*", "Their Patch")
    refute has_element?(index_live, "*", "Common Special")
    assert has_element?(index_live, "#common-locations-count", "1")
  end

  test "a country links to its admin show page", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "a[href='/admin/locations/#{country.slug}']", "Canada")
  end

  test "countries start collapsed with a toggle for their subdivisions", %{conn: conn} do
    country = insert(:country, name_en: "Canada")
    insert(:subdivision1, name_en: "Manitoba", country: country)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "#tree-body-#{country.id}.hidden")
    assert has_element?(index_live, "button[aria-controls='tree-body-#{country.id}']")
  end

  test "rows carry no lifelist links", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    refute has_element?(index_live, "a[href='/my/lifelist/#{country.slug}']")
  end

  test "shows the empty state when there are no common locations", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "p", "No common locations yet")
  end

  test "links to the new location form", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "#new-location-button[href='/admin/locations/new']")
  end

  test "marks a disabled country with the disabled icon", %{conn: conn} do
    insert(:country, name_en: "Nowhere", iso_code: "XX", disabled: true)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "span[title='Disabled']")
  end

  test "does not mark an enabled country", %{conn: conn} do
    insert(:country, name_en: "Andorra", iso_code: "AD", disabled: false)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    refute has_element?(index_live, "span[title='Disabled']")
  end

  test "shows a country's flag by default", %{conn: conn} do
    insert(:country, name_en: "Andorra", iso_code: "AD", hide_flag: false)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    assert has_element?(index_live, "span[aria-hidden='true']", "🇦🇩")
  end

  test "hides a country's flag when hide_flag is set", %{conn: conn} do
    insert(:country, name_en: "Andorra", iso_code: "AD", hide_flag: true)

    {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

    refute has_element?(index_live, "span[aria-hidden='true']", "🇦🇩")
  end

  describe "eBird match status" do
    test "a country row carries its status badge linking to the workbench", %{conn: conn} do
      country = insert(:country, name_en: "Andorra", iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      assert has_element?(index_live, "a[href='/admin/ebird/AD']", "matched")
    end

    test "an unmatched eBird country shows on its ISO counterpart", %{conn: conn} do
      insert(:country, name_en: "Czechia", iso_code: "CZ")
      insert(:ebird_location, code: "CZ")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      assert has_element?(index_live, "a[href='/admin/ebird/CZ']", "unmatched")
    end

    test "status chips filter the tree to matching countries", %{conn: conn} do
      matched = insert(:country, name_en: "Andorra", iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: matched.id)
      insert(:country, name_en: "Czechia", iso_code: "CZ")
      insert(:ebird_location, code: "CZ")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations?status=matched")

      assert has_element?(index_live, "a", "Andorra")
      refute has_element?(index_live, "a", "Czechia")
      assert has_element?(index_live, "#ebird-status-filter", "matched (1)")
      assert has_element?(index_live, "#ebird-status-filter", "unmatched (1)")
    end

    test "the no-eBird chip finds countries without an eBird counterpart", %{conn: conn} do
      insert(:country, name_en: "Bonaire", iso_code: "BQ")
      matched = insert(:country, name_en: "Andorra", iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: matched.id)

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations?status=no_ebird")

      assert has_element?(index_live, "a", "Bonaire")
      refute has_element?(index_live, "a", "Andorra")
    end

    test "shows the empty state when no country has the status", %{conn: conn} do
      insert(:country, name_en: "Bonaire", iso_code: "BQ")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations?status=matched")

      assert has_element?(index_live, "p", "No countries with this status")
    end
  end

  describe "search" do
    test "shows common locations matching the query", %{conn: conn} do
      insert(:country, name_en: "Canada")
      insert(:country, name_en: "Mongolia")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      html =
        index_live
        |> element("#location-search")
        |> render_keyup(%{"value" => "Canada"})

      assert has_element?(index_live, "h2", "Search Results")
      assert html =~ "Canada"
      # The tree is hidden while searching, so a non-matching country is absent.
      refute has_element?(index_live, "a", "Mongolia")
    end

    test "does not find personal locations", %{conn: conn} do
      insert(:location, name_en: "Canadian Patch", user_id: user_fixture().id)

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Canadian"})

      assert has_element?(index_live, "p", "No locations found")
    end

    test "a result links to the admin show page without a lifelist link", %{conn: conn} do
      country = insert(:country, name_en: "Canada", slug: "canada")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Canada"})

      assert has_element?(index_live, "a[href='/admin/locations/#{country.slug}']", "Canada")
      refute has_element?(index_live, "a[href='/my/lifelist/#{country.slug}']")
    end

    test "hides the tree while searching and restores it on clear", %{conn: conn} do
      country = insert(:country, name_en: "Mongolia")

      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Canada"})

      refute has_element?(index_live, "#tree-body-#{country.id}")

      index_live
      |> element("#location-search + button[aria-label='Clear']")
      |> render_click()

      refute has_element?(index_live, "h2", "Search Results")
      assert has_element?(index_live, "a", "Mongolia")
    end

    test "asks for at least 2 characters", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "C"})

      assert has_element?(index_live, "*", "Type at least 2 characters")
      refute has_element?(index_live, "h2", "Search Results")
    end
  end
end
