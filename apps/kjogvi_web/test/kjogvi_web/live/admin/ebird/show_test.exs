defmodule KjogviWeb.Live.Admin.Ebird.ShowTest do
  use KjogviWeb.ConnCase, async: true

  @moduletag :capture_log

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  setup %{conn: conn} do
    %{conn: login_user(conn, admin_fixture())}
  end

  defp reload(ebird_row), do: Repo.get!(EbirdLocation, ebird_row.id)

  test "returns 404 for a non-admin user", %{conn: _conn} do
    insert(:ebird_location, code: "AD")
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/ebird/AD")

    assert response(conn, 404)
  end

  test "redirects to the index for an unknown country code", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/ebird"}}} = live(conn, ~p"/admin/ebird/ZZ")
  end

  test "renders the country header with status and regions", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    ebird_country = insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    assert has_element?(view, "h1", "Andorra")
    # ISO has no subdivisions here while eBird has AD-02.
    assert has_element?(view, "#ebird-country-status", "eBird-only subregions")
    assert has_element?(view, "#ebird-sub1-counts", "0/1 subdivisions linked")

    assert has_element?(view, "#ebird-region-#{ebird_country.id}", "Andorra")
    # A code-consistent link is the norm and carries no badge.
    refute has_element?(view, "#ebird-region-#{ebird_country.id}", "other")
    assert has_element?(view, "#ebird-region-#{ebird_country.id} button", "Unlink")

    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "Canillo")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Link")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Create from eBird")
  end

  test "hides create for a subdivision an ISO one can be linked to", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    by_code = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")
    insert(:subdivision1, country: country, iso_code: "AD-02", name_en: "Canillo")
    # Codes differ, so only the name pass pairs this one.
    by_name = insert(:ebird_subdivision1, country_code: "AD", code: "AD-99", name: "Encamp")
    insert(:subdivision1, country: country, iso_code: "AD-03", name_en: "Encamp")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    for region <- [by_code, by_name] do
      assert has_element?(view, "#ebird-region-#{region.id} button", "Link")
      refute has_element?(view, "#ebird-region-#{region.id} button", "Create from eBird")
    end
  end

  test "links a suggested pair outright, without the autocomplete", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")
    location = insert(:subdivision1, country: country, iso_code: "AD-02", name_en: "Canillo")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    view |> element("#ebird-region-#{ebird_sub1.id} button", "Link") |> render_click()

    assert reload(ebird_sub1).location_id == location.id
    assert has_element?(view, "#flash-group-info", "Linked AD-02 to Canillo.")
    refute has_element?(view, "#link-autocomplete-#{ebird_sub1.id}")
  end

  test "links by name when the codes differ", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-99", name: "Encamp")
    location = insert(:subdivision1, country: country, iso_code: "AD-03", name_en: "Encamp")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    view |> element("#ebird-region-#{ebird_sub1.id} button", "Link") |> render_click()

    assert reload(ebird_sub1).location_id == location.id
  end

  test "opens the autocomplete for a region with nothing to suggest", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", name: "Andorra", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02", name: "Canillo")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    view |> element("#ebird-region-#{ebird_sub1.id} button", "Link") |> render_click()

    assert has_element?(view, "#link-autocomplete-#{ebird_sub1.id}")
    assert reload(ebird_sub1).location_id == nil
  end

  test "marks a non-code-consistent link", %{conn: conn} do
    country = insert(:country, iso_code: "RS", name_en: "Serbia")
    ebird_country = insert(:ebird_location, code: "XK", name: "Kosovo", location_id: country.id)

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/XK")

    assert has_element?(view, "#ebird-region-#{ebird_country.id}", "other")
  end

  test "run match links regions by code", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    sub1 = insert(:subdivision1, iso_code: "AD-02", country: country)
    ebird_country = insert(:ebird_location, code: "AD")
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    view |> element("#run-match-button") |> render_click()

    assert has_element?(view, "#flash-group-info", "Matched 2 by code")
    assert has_element?(view, "#ebird-country-status", "matched")
    assert reload(ebird_country).location_id == country.id
    assert reload(ebird_sub1).location_id == sub1.id
  end

  test "unlink clears the link", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    ebird_country = insert(:ebird_location, code: "AD", location_id: country.id)

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    view |> element("#ebird-region-#{ebird_country.id} button", "Unlink") |> render_click()

    assert has_element?(view, "#flash-group-info", "Unlinked AD.")
    assert has_element?(view, "#ebird-region-#{ebird_country.id}", "unmatched")
    assert reload(ebird_country).location_id == nil
  end

  test "links a region picked in the autocomplete", %{conn: conn} do
    country = insert(:country, iso_code: "AD")
    sub1 = insert(:subdivision1, iso_code: "AD-02", name_en: "Canillo", country: country)
    insert(:ebird_location, code: "AD", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-02")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    send(
      view.pid,
      {:autocomplete_select, "link_selected", %{"result" => sub1, "ebird_id" => ebird_sub1.id}}
    )

    assert render(view) =~ "Linked AD-02 to Canillo."
    assert has_element?(view, "#ebird-country-status", "matched")
    assert reload(ebird_sub1).location_id == sub1.id
  end

  test "linking a location taken by another eBird row shows an error", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", location_id: country.id)
    ebird_other = insert(:ebird_location, code: "XY")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/XY")

    send(
      view.pid,
      {:autocomplete_select, "link_selected",
       %{"result" => country, "ebird_id" => ebird_other.id}}
    )

    assert render(view) =~ "already linked to another eBird region"
    assert reload(ebird_other).location_id == nil
  end

  test "creates a common location from an eBird-only country", %{conn: conn} do
    ebird_country = insert(:ebird_location, code: "XK", name: "Kosovo")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/XK")

    view
    |> element("#ebird-region-#{ebird_country.id} button", "Create from eBird")
    |> render_click()

    assert has_element?(view, "#flash-group-info", "Created Kosovo and linked XK.")
    # XK has no ISO counterpart, so its shape stays :ebird_only after linking.
    assert has_element?(view, "#ebird-country-status", "eBird only")

    location = Repo.preload(reload(ebird_country), :location).location
    assert location.slug == "xk"
    assert location.user_id == nil
  end

  test "hides create for a subdivision while the country is unlinked", %{conn: conn} do
    insert(:ebird_location, code: "XK", name: "Kosovo")
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "XK", code: "XK-01")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/XK")

    assert has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Link")
    refute has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Create from eBird")
  end

  test "shows ISO subdivisions without an eBird counterpart in the comparison", %{conn: conn} do
    country = insert(:country, iso_code: "HU", name_en: "Hungary")
    extra = insert(:subdivision1, iso_code: "HU-BA", name_en: "Baranya", country: country)
    insert(:ebird_location, code: "HU", location_id: country.id)

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/HU")

    assert has_element?(view, "#iso-leftover-#{extra.id}", "Baranya")
    assert has_element?(view, "#iso-leftover-#{extra.id}", "no eBird region")
    refute has_element?(view, "#iso-leftover-#{extra.id} button")
  end

  test "pairs a linked subdivision with its ISO counterpart", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    sub1 = insert(:subdivision1, iso_code: "AD-02", name_en: "Canillo", country: country)
    insert(:ebird_location, code: "AD", location_id: country.id)

    ebird_sub1 =
      insert(:ebird_subdivision1,
        country_code: "AD",
        code: "AD-02",
        name: "Canillo",
        location_id: sub1.id
      )

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "Canillo")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Unlink")
    refute has_element?(view, "#ebird-region-#{ebird_sub1.id}", "no ISO subdivision")
  end

  test "pairs an unlinked same-code row with its ISO counterpart", %{conn: conn} do
    country = insert(:country, iso_code: "BA", name_en: "Bosnia and Herzegovina")

    insert(:subdivision1,
      iso_code: "BA-BIH",
      name_en: "Federacija Bosne i Hercegovine",
      country: country
    )

    insert(:ebird_location, code: "BA", location_id: country.id)

    ebird_sub1 =
      insert(:ebird_subdivision1,
        country_code: "BA",
        code: "BA-BIH",
        name: "Federacija Bosna i Hercegovina"
      )

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/BA")

    # Both spellings land on one row: the code pairs them though the names differ.
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "Federacija Bosna i Hercegovina")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "Federacija Bosne i Hercegovine")
    refute has_element?(view, "#ebird-region-#{ebird_sub1.id}", "no ISO subdivision")
    refute has_element?(view, "#ebird-region-#{ebird_sub1.id}", "by name")
  end

  test "marks an unlinked name match as a suggestion", %{conn: conn} do
    country = insert(:country, iso_code: "PL", name_en: "Poland")
    insert(:subdivision1, iso_code: "PL-LD", name_en: "Łódzkie", country: country)
    insert(:ebird_location, code: "PL", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "PL", code: "PL-91", name: "Lodzkie")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/PL")

    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "by name")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "Łódzkie")
    assert has_element?(view, "#ebird-region-#{ebird_sub1.id} button", "Link")
  end

  test "shows an eBird subdivision with no ISO counterpart", %{conn: conn} do
    country = insert(:country, iso_code: "AD", name_en: "Andorra")
    insert(:ebird_location, code: "AD", location_id: country.id)
    ebird_sub1 = insert(:ebird_subdivision1, country_code: "AD", code: "AD-ZZ", name: "High Seas")

    {:ok, view, _html} = live(conn, ~p"/admin/ebird/AD")

    assert has_element?(view, "#ebird-region-#{ebird_sub1.id}", "no ISO subdivision")
  end
end
