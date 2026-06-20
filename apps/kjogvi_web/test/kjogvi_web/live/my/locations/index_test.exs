defmodule KjogviWeb.Live.My.Locations.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
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

  test "shows the user's own and common locations but not another user's",
       %{conn: conn, user: user} do
    own = insert(:location, name_en: "My Patch", location_type: "city", user_id: user.id)
    common = insert(:location, name_en: "Shared Place", location_type: "city")

    other =
      insert(:location, name_en: "Their Patch", location_type: "city", user_id: user_fixture().id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", own.name_en)
    assert has_element?(index_live, "a", common.name_en)
    refute has_element?(index_live, "a", other.name_en)
  end

  test "shows the user's own special location but not another user's", %{conn: conn, user: user} do
    own = insert(:location, name_en: "My List", location_type: "special", user_id: user.id)

    other =
      insert(:location,
        name_en: "Their List",
        location_type: "special",
        user_id: user_fixture().id
      )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "*", own.name_en)
    refute has_element?(index_live, "*", other.name_en)
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

  test "row shows edit link for the user's own location", %{conn: conn, user: user} do
    location = insert(:location, name_en: "Winnipeg", location_type: "city", user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a[href='/my/locations/#{location.slug}/edit']")
  end

  test "row hides edit link and delete button for a common location", %{conn: conn} do
    location = insert(:location, name_en: "Common Place", location_type: "city")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    refute has_element?(index_live, "a[href='/my/locations/#{location.slug}/edit']")
    refute has_element?(index_live, "button[phx-click='delete'][phx-value-id='#{location.id}']")
  end

  test "row shows delete button when the user's own location can be deleted",
       %{conn: conn, user: user} do
    location = insert(:location, name_en: "Empty", location_type: "city", user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "button[phx-click='delete'][phx-value-id='#{location.id}']")
  end

  test "deleting a location with children fails with an error and keeps it",
       %{conn: conn, user: user} do
    parent = insert(:location, name_en: "Canada", location_type: "country", user_id: user.id)
    insert(:location, name_en: "Manitoba", location_type: "subdivision1", country_id: parent.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    html =
      index_live
      |> element("button[phx-click='delete'][phx-value-id='#{parent.id}']")
      |> render_click()

    assert html =~ "sub-locations"
    refute is_nil(Kjogvi.Repo.get(Kjogvi.Geo.Location, parent.id))
  end

  test "deleting a location with cards fails with an error and keeps it",
       %{conn: conn, user: user} do
    location = insert(:location, name_en: "With Cards", location_type: "city", user_id: user.id)
    insert(:card, location: location)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    html =
      index_live
      |> element("button[phx-click='delete'][phx-value-id='#{location.id}']")
      |> render_click()

    assert html =~ "has cards"
    refute is_nil(Kjogvi.Repo.get(Kjogvi.Geo.Location, location.id))
  end

  test "deletes a location", %{conn: conn, user: user} do
    location = insert(:location, name_en: "Doomed", location_type: "city", user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    index_live
    |> element("button[phx-click='delete'][phx-value-id='#{location.id}']")
    |> render_click()

    refute has_element?(index_live, "a", "Doomed")
    assert is_nil(Kjogvi.Repo.get(Kjogvi.Geo.Location, location.id))
  end

  describe "search" do
    test "shows results matching the query", %{conn: conn} do
      insert(:location, name_en: "Winnipeg")
      insert(:location, name_en: "Toronto")

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      html =
        index_live
        |> element("#location-search")
        |> render_keyup(%{"value" => "Winnipeg"})

      assert has_element?(index_live, "h2", "Search Results")
      assert html =~ "Winnipeg"
    end

    test "clears results when the input is emptied", %{conn: conn} do
      insert(:location, name_en: "Winnipeg")

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Winnipeg"})

      assert has_element?(index_live, "h2", "Search Results")

      index_live
      |> element("#location-search + button[aria-label='Clear']")
      |> render_click()

      refute has_element?(index_live, "h2", "Search Results")
    end
  end

  test "lists all locations flat regardless of hierarchy", %{conn: conn} do
    country = insert(:location, name_en: "Germany", location_type: "country")
    insert(:location, name_en: "Berlin", location_type: "city", country_id: country.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", "Germany")
    assert has_element?(index_live, "a", "Berlin")
  end
end
