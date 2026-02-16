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

    assert has_element?(index_live, "span", "2 total locations")
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
