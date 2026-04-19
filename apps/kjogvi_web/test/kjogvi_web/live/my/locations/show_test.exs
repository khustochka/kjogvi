defmodule KjogviWeb.Live.My.Locations.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "renders location name and slug", %{conn: conn} do
    location = insert(:location, name_en: "Manitoba", slug: "ca-mb")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "h1", "Manitoba")
    assert has_element?(show_live, "#location-details", "ca-mb")
  end

  test "shows full long name as subtitle when richer than name_en", %{conn: conn} do
    country = insert(:location, name_en: "Canada", location_type: "country")

    location =
      insert(:location,
        name_en: "Manitoba",
        location_type: "region",
        ancestry: [country.id],
        cached_country_id: country.id
      )

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-full-name", "Manitoba, Canada")
  end

  test "omits full name subtitle when equal to name_en", %{conn: conn} do
    location = insert(:location, name_en: "Solo")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-full-name")
  end

  test "shows breadcrumbs with link to all locations", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a", "Locations")
  end

  test "shows ancestor locations in breadcrumbs", %{conn: conn} do
    parent = insert(:location, name_en: "Canada", location_type: "country")
    child = insert(:location, name_en: "Manitoba", ancestry: [parent.id])

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{child.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a", "Canada")
    assert has_element?(show_live, "#location-breadcrumbs span", "Manitoba")
  end

  test "shows stats with cards count and lifelist link", %{conn: conn} do
    location = insert(:location, name_en: "Manitoba")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-stats")
    assert has_element?(show_live, "#lifelist-link", "Lifelist")
  end

  test "shows location type badge", %{conn: conn} do
    location = insert(:location, name_en: "Canada", location_type: "country")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "span", "country")
  end

  test "lists direct children", %{conn: conn} do
    parent = insert(:location, name_en: "Canada", location_type: "country")

    child1 =
      insert(:location, name_en: "Manitoba", ancestry: [parent.id], location_type: "region")

    child2 = insert(:location, name_en: "Ontario", ancestry: [parent.id], location_type: "region")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{parent.slug}")

    assert has_element?(show_live, "#location-children")
    assert has_element?(show_live, "#location-children a", child1.name_en)
    assert has_element?(show_live, "#location-children a", child2.name_en)
  end

  test "does not show children section when there are none", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-children")
  end

  test "shows member locations for special location", %{conn: conn} do
    special = insert(:location, name_en: "My Patch", location_type: "special")
    member1 = insert(:location, name_en: "Park A")
    member2 = insert(:location, name_en: "Park B")

    Kjogvi.Repo.insert_all("special_locations", [
      %{parent_location_id: special.id, child_location_id: member1.id},
      %{parent_location_id: special.id, child_location_id: member2.id}
    ])

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{special.slug}")

    assert has_element?(show_live, "#location-members")
    assert has_element?(show_live, "#location-members a", "Park A")
    assert has_element?(show_live, "#location-members a", "Park B")
  end

  test "does not show members section for non-special location", %{conn: conn} do
    location = insert(:location, name_en: "Canada", location_type: "country")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-members")
  end

  test "shows lifelist badge when location has public_index", %{conn: conn} do
    location = insert(:location, name_en: "Canada", public_index: 1)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-details span", "lifelist filter")
  end

  test "does not show lifelist badge when location has no public_index", %{conn: conn} do
    location = insert(:location, name_en: "Local Park", public_index: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "span", "lifelist filter")
  end

  test "delete button enabled for empty location", %{conn: conn} do
    location = insert(:location, name_en: "Empty")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#delete-location-button[disabled]")
  end

  test "delete button disabled when location has children", %{conn: conn} do
    parent = insert(:location, name_en: "Canada")
    insert(:location, name_en: "Manitoba", ancestry: [parent.id])

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{parent.slug}")

    assert has_element?(show_live, "#delete-location-button[disabled]")
  end

  test "delete button disabled when location has cards", %{conn: conn} do
    location = insert(:location, name_en: "With Cards")
    insert(:card, location: location)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#delete-location-button[disabled]")
  end

  describe "static map" do
    setup do
      original = Application.get_env(:kjogvi_web, :google_maps)
      on_exit(fn -> Application.put_env(:kjogvi_web, :google_maps, original) end)
      :ok
    end

    test "renders when coords present and api key configured", %{conn: conn} do
      Application.put_env(:kjogvi_web, :google_maps, api_key: "test-key")
      location = insert(:location, name_en: "Has Coords", lat: 49.8951, lon: -97.1384)

      {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

      assert has_element?(show_live, "#location-map img")
    end

    test "hidden when api key missing", %{conn: conn} do
      Application.put_env(:kjogvi_web, :google_maps, api_key: nil)
      location = insert(:location, name_en: "Has Coords", lat: 49.8951, lon: -97.1384)

      {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

      refute has_element?(show_live, "#location-map")
    end

    test "hidden when coords missing", %{conn: conn} do
      Application.put_env(:kjogvi_web, :google_maps, api_key: "test-key")
      location = insert(:location, name_en: "No Coords", lat: nil, lon: nil)

      {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

      refute has_element?(show_live, "#location-map")
    end
  end

  test "redirects to index for nonexistent slug", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/my/locations"}}} =
             live(conn, ~p"/my/locations/nonexistent")
  end
end
