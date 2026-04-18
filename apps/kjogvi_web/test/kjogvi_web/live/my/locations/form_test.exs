defmodule KjogviWeb.Live.My.Locations.FormTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  describe "new" do
    test "renders new location form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/locations/new")

      assert has_element?(view, "#location-form")
      assert has_element?(view, "#location-breadcrumbs a", "Locations")
    end

    test "creates a top-level location", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/locations/new")

      {:ok, _show, _html} =
        view
        |> form("#location-form",
          location: %{
            slug: "greenland",
            name_en: "Greenland",
            location_type: "country",
            is_private: "false",
            is_patch: "false",
            is_5mr: "false"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      loc = Geo.location_by_slug("greenland")
      assert loc.name_en == "Greenland"
      assert loc.ancestry == []
    end

    test "prefills parent when parent_id query param is given", %{conn: conn} do
      parent = insert(:location, name_en: "Canada", location_type: "country")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{parent.id}")

      assert has_element?(view, "#location_parent_search")
      # Clear button is shown when parent is set
      assert has_element?(view, "button[phx-click='clear_parent']")
    end
  end

  describe "edit" do
    test "renders edit form with current values", %{conn: conn} do
      location = insert(:location, name_en: "Manitoba", slug: "mb")

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      assert has_element?(view, "#location-form")
      assert has_element?(view, "#location-breadcrumbs a", "Manitoba")
    end

    test "updates a location", %{conn: conn} do
      location = insert(:location, name_en: "Manitoba", slug: "mb")

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      {:ok, _show, _html} =
        view
        |> form("#location-form",
          location: %{
            slug: "mb",
            name_en: "Manitoba (updated)",
            is_private: "false",
            is_patch: "false",
            is_5mr: "false"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert Repo.get(Location, location.id).name_en == "Manitoba (updated)"
    end

    test "redirects for nonexistent slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/my/locations"}}} =
               live(conn, ~p"/my/locations/nonexistent/edit")
    end
  end

  describe "changeset cached_public_location_id derivation" do
    test "sets cached_public_location_id for private location to nearest public ancestor" do
      country = insert(:location, name_en: "Canada", is_private: false)

      private_parent =
        insert(:location, name_en: "Private area", is_private: true, ancestry: [country.id])

      {:ok, created} =
        Geo.create_location(%{
          "slug" => "secret-patch",
          "name_en" => "Secret Patch",
          "is_private" => "true",
          "is_patch" => "false",
          "is_5mr" => "false",
          "parent_id" => private_parent.id
        })

      assert created.cached_public_location_id == country.id
      assert created.ancestry == [country.id, private_parent.id]
    end

    test "leaves cached_public_location_id nil for public location" do
      country = insert(:location, name_en: "Canada", is_private: false)

      {:ok, created} =
        Geo.create_location(%{
          "slug" => "city-x",
          "name_en" => "City X",
          "is_private" => "false",
          "is_patch" => "false",
          "is_5mr" => "false",
          "parent_id" => country.id
        })

      assert is_nil(created.cached_public_location_id)
    end
  end
end
