defmodule KjogviWeb.Live.Admin.Locations.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    %{conn: login_user(conn, admin_fixture())}
  end

  test "renders a common location's details", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada", iso_code: "ca")

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    assert has_element?(show_live, "h1", "Canada")
    assert has_element?(show_live, "#location-details", "canada")
    assert has_element?(show_live, "#location-details", "CA")
    assert has_element?(show_live, "#location-details span", "country")
  end

  test "breadcrumbs lead back to the admin index through the ancestors", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")
    subdivision = insert(:subdivision1, name_en: "Manitoba", country: country)

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{subdivision.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a[href='/admin/locations']")

    assert has_element?(
             show_live,
             "#location-breadcrumbs a[href='/admin/locations/canada']",
             "Canada"
           )
  end

  test "lists ancestors and links them to their admin pages", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")
    subdivision = insert(:subdivision1, name_en: "Manitoba", country: country)

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{subdivision.slug}")

    assert has_element?(show_live, "#location-ancestry a[href='/admin/locations/canada']")
  end

  test "lists common children only, not personal locations", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")
    insert(:subdivision1, name_en: "Manitoba", country: country)
    insert(:location, name_en: "Their Patch", country: country, user_id: user_fixture().id)

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    assert has_element?(show_live, "#location-children", "Manitoba")
    refute has_element?(show_live, "#location-children", "Their Patch")
  end

  test "counts checklists across all users", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")
    insert(:checklist, location: country, user: user_fixture())
    insert(:checklist, location: country, user: user_fixture())

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    assert has_element?(show_live, "#location-checklists-count", "2")
  end

  test "hides the checklists count when there are none", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    refute has_element?(show_live, "#location-checklists-count")
  end

  test "shows edit, add sub-location, and delete actions but no lifelist link", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    assert has_element?(show_live, "#edit-location-button[href='/admin/locations/canada/edit']")

    assert has_element?(
             show_live,
             "#add-sub-location-button[href='/admin/locations/new?parent_id=#{country.id}']"
           )

    assert has_element?(show_live, "#delete-location-button")
    refute has_element?(show_live, "a[href='/my/lifelist/#{country.slug}']")
  end

  describe "delete" do
    test "deletes an unused common location and returns to the index", %{conn: conn} do
      country = insert(:country, name_en: "Canada", slug: "canada")

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      refute has_element?(show_live, "#delete-location-button[disabled]")

      show_live
      |> element("#delete-location-button")
      |> render_click()

      flash = assert_redirect(show_live, "/admin/locations")
      assert flash["info"] == "Location deleted"
      assert Kjogvi.Repo.get(Kjogvi.Geo.Location, country.id) == nil
    end

    test "the button is disabled when the location has children", %{conn: conn} do
      country = insert(:country, name_en: "Canada", slug: "canada")
      insert(:subdivision1, country: country)

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      assert has_element?(show_live, "#delete-location-button[disabled]")
    end

    test "the button is disabled when an eBird region links here", %{conn: conn} do
      country = insert(:country, name_en: "Canada", slug: "canada", iso_code: "CA")
      insert(:ebird_location, code: "CA", location_id: country.id)

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      assert has_element?(show_live, "#delete-location-button[disabled]")
    end
  end

  describe "eBird details" do
    test "shows the eBird code linking to the workbench and the status badge", %{conn: conn} do
      country = insert(:country, name_en: "Andorra", slug: "andorra", iso_code: "AD")
      insert(:ebird_location, code: "AD", location_id: country.id)

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      assert has_element?(
               show_live,
               "#location-ebird-code a[href='/admin/ebird/locations/AD']",
               "AD"
             )

      assert has_element?(show_live, "#location-ebird-status", "matched")
    end

    test "an unlinked country still shows its would-be status", %{conn: conn} do
      country = insert(:country, name_en: "Czechia", slug: "czechia", iso_code: "CZ")
      insert(:ebird_location, code: "CZ")
      # Both sides subdivide but agree on neither code nor name, so CZ's shape is
      # :mixed; without any subdivisions it would be a trivially matched empty set.
      insert(:subdivision1, iso_code: "CZ-10", name_en: "Praha", country: country)
      insert(:ebird_subdivision1, country_code: "CZ", code: "CZ-99", name: "No Match")

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      refute has_element?(show_live, "#location-ebird-code")
      assert has_element?(show_live, "#location-ebird-status", "mixed")
    end

    test "a country with no eBird counterpart shows neither", %{conn: conn} do
      country = insert(:country, name_en: "Bonaire", slug: "bonaire", iso_code: "BQ")

      {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

      refute has_element?(show_live, "#location-ebird-code")
      refute has_element?(show_live, "#location-ebird-status")
    end
  end

  test "marks the header and details for a disabled location", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada", disabled: true)

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    assert has_element?(show_live, "h1 span[title='Disabled']")
    assert has_element?(show_live, "#location-details span", "disabled")
  end

  test "does not mark an enabled location as disabled", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada", disabled: false)

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    refute has_element?(show_live, "h1 span[title='Disabled']")
    refute has_element?(show_live, "#location-details span", "disabled")
  end

  test "redirects to the index for an unknown slug", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/admin/locations"}}} =
             live(conn, ~p"/admin/locations/nonexistent")
  end

  test "redirects for a user-owned location's slug", %{conn: conn} do
    location = insert(:location, slug: "personal-loc", user_id: user_fixture().id)

    assert {:error, {:redirect, %{to: "/admin/locations"}}} =
             live(conn, ~p"/admin/locations/#{location.slug}")
  end
end
