defmodule KjogviWeb.Live.Admin.Locations.FormTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  setup %{conn: conn} do
    %{conn: login_user(conn, admin_fixture())}
  end

  test "returns 404 for a non-admin user", %{conn: _conn} do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/locations/new")

    assert response(conn, 404)
  end

  describe "new" do
    test "renders the form with admin breadcrumbs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/locations/new")

      assert has_element?(view, "#location-form")
      assert has_element?(view, "#location-breadcrumbs a[href='/admin/locations']")
    end

    test "the type select offers the common-only types but not special", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/locations/new")

      assert has_element?(view, "#location_location_type option[value='country']")
      assert has_element?(view, "#location_location_type option[value='subdivision1']")
      refute has_element?(view, "#location_location_type option[value='special']")
    end

    test "creates a common country", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/locations/new")

      view
      |> form("#location-form",
        location: %{
          slug: "greenland",
          name_en: "Greenland",
          location_type: "country",
          is_private: "false"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/locations/greenland")

      saved = Geo.location_by_slug("greenland")
      assert saved.user_id == nil
      assert saved.location_type == :country
    end

    test "creates a subdivision1 under the parent from the query param", %{conn: conn} do
      country = insert(:country, name_en: "Greenland")

      {:ok, view, _html} = live(conn, ~p"/admin/locations/new?parent_id=#{country.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "gl-north",
          name_en: "North Greenland",
          location_type: "subdivision1",
          is_private: "false"
        }
      )
      |> render_submit()

      saved = Geo.location_by_slug("gl-north")
      assert saved.user_id == nil
      assert saved.country_id == country.id
    end

    test "parent autocomplete suggests common locations only", %{conn: conn} do
      insert(:country, name_en: "Park Country")

      insert(:location,
        name_en: "Park Personal",
        location_type: :city,
        user_id: user_fixture().id
      )

      {:ok, view, _html} = live(conn, ~p"/admin/locations/new")

      view |> element("#location_parent_search") |> render_keyup(%{"value" => "Park"})

      assert has_element?(view, "#location_parent_search-result-0", "Park Country")
      refute has_element?(view, "#location_parent_search-results", "Park Personal")
    end
  end

  describe "edit" do
    test "updates a common location, keeping it common", %{conn: conn} do
      country = insert(:country, name_en: "Greenland", slug: "greenland")

      {:ok, view, _html} = live(conn, ~p"/admin/locations/greenland/edit")

      view
      |> form("#location-form",
        location: %{
          slug: "greenland",
          name_en: "Kalaallit Nunaat",
          location_type: "country",
          is_private: "false"
        }
      )
      |> render_submit()

      assert_redirect(view, ~p"/admin/locations/greenland")

      updated = Repo.get(Location, country.id)
      assert updated.name_en == "Kalaallit Nunaat"
      assert updated.user_id == nil
    end

    test "redirects for a nonexistent slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/admin/locations"}}} =
               live(conn, ~p"/admin/locations/nonexistent/edit")
    end

    test "a user-owned location reads as not found", %{conn: conn} do
      location = insert(:location, slug: "personal-loc", user_id: user_fixture().id)

      assert {:error, {:live_redirect, %{to: "/admin/locations"}}} =
               live(conn, ~p"/admin/locations/#{location.slug}/edit")
    end

    test "redirects away from a common special", %{conn: conn} do
      insert(:special, name_en: "Western Palearctic", slug: "wp")

      assert {:error, {:live_redirect, %{to: "/admin/locations/wp"}}} =
               live(conn, ~p"/admin/locations/wp/edit")
    end
  end
end
