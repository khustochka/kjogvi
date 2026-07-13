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

  test "shows each country with its status and subdivision counts", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", location_id: sub1.id)
    insert(:ebird_subdivision1, country_code: "AD", code: "AD-03")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "#ebird-country-AD", "Andorra")
    assert has_element?(view, "#ebird-country-AD", "partial")
    assert has_element?(view, "#ebird-country-AD", "1/2 subdivisions linked")
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
    |> element("#ebird-status-filter a", "unmatched")
    |> render_click()

    refute has_element?(view, "#ebird-country-AD")
    assert has_element?(view, "#ebird-country-CZ")
  end

  test "shows an empty state when the dataset is empty", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/admin/ebird")

    assert has_element?(view, "p", "No eBird locations yet")
  end
end
