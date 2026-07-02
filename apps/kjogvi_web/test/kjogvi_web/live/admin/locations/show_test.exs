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

  test "shows no edit, delete, or lifelist actions", %{conn: conn} do
    country = insert(:country, name_en: "Canada", slug: "canada")

    {:ok, show_live, _html} = live(conn, ~p"/admin/locations/#{country.slug}")

    refute has_element?(show_live, "a", "Edit")
    refute has_element?(show_live, "button", "Delete")
    refute has_element?(show_live, "a[href='/my/lifelist/#{country.slug}']")
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
