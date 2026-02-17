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
    assert has_element?(show_live, "span", "ca-mb")
  end

  test "shows breadcrumbs with link to all locations", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a", "All locations")
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

  test "redirects to index for nonexistent slug", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/my/locations"}}} =
             live(conn, ~p"/my/locations/nonexistent")
  end
end
