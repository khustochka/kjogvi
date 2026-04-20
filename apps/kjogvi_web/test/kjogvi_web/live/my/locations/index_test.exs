defmodule KjogviWeb.Live.My.Locations.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "renders with no locations", %{conn: conn} do
    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "h1", "Locations")
  end

  test "renders a location in the hierarchy", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", location.name_en)
  end

  test "shows total location count", %{conn: conn} do
    insert(:location)
    insert(:location)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    # Total count is shown in a stat pill with the number in its own span
    assert has_element?(index_live, "span", "2")
    assert has_element?(index_live, "span", "total")
  end

  test "shows lifelist badge for location with public_index", %{conn: conn} do
    insert(:location, name_en: "Canada", public_index: 1)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "span", "lifelist filter")
  end

  test "does not show lifelist badge for location without public_index", %{conn: conn} do
    insert(:location, name_en: "Local Park", public_index: nil)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    refute has_element?(index_live, "span", "lifelist filter")
  end

  test "row shows edit link for every location", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a[href='/my/locations/#{location.slug}/edit']")
  end

  test "row shows delete button when location can be deleted", %{conn: conn} do
    location = insert(:location, name_en: "Empty")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "button[phx-click='delete'][phx-value-id='#{location.id}']")
  end

  test "row hides delete button when location has children", %{conn: conn} do
    parent = insert(:location, name_en: "Canada")
    insert(:location, name_en: "Manitoba", ancestry: [parent.id])

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    refute has_element?(index_live, "button[phx-click='delete'][phx-value-id='#{parent.id}']")
  end

  test "row hides delete button when location has cards", %{conn: conn} do
    location = insert(:location, name_en: "With Cards")
    insert(:card, location: location)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    refute has_element?(index_live, "button[phx-click='delete'][phx-value-id='#{location.id}']")
  end

  test "deletes a location", %{conn: conn} do
    location = insert(:location, name_en: "Doomed")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    index_live
    |> element("button[phx-click='delete'][phx-value-id='#{location.id}']")
    |> render_click()

    refute has_element?(index_live, "a", "Doomed")
    assert is_nil(Kjogvi.Repo.get(Kjogvi.Geo.Location, location.id))
  end

  test "expands and collapses a parent location", %{conn: conn} do
    parent = insert(:location, name_en: "Europe", location_type: "continent")
    insert(:location, name_en: "Germany", ancestry: [parent.id], location_type: "country")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    # Parent should be auto-expanded (top-level), so child is visible
    assert has_element?(index_live, "a", "Germany")

    # Collapse
    index_live |> element("button[phx-value-location_id='#{parent.id}']") |> render_click()
    refute has_element?(index_live, "a", "Germany")

    # Expand again
    index_live |> element("button[phx-value-location_id='#{parent.id}']") |> render_click()
    assert has_element?(index_live, "a", "Germany")
  end
end
