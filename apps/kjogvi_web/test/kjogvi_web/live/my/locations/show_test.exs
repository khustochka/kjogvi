defmodule KjogviWeb.Live.My.Locations.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  test "renders location name and slug", %{conn: conn} do
    location = insert(:location, name_en: "Manitoba", slug: "ca-mb")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "h1", "Manitoba")
    assert has_element?(show_live, "#location-details", "ca-mb")
  end

  test "shows full long name as subtitle when richer than name_en", %{conn: conn} do
    country = insert(:country, name_en: "Canada")

    location =
      insert(:location,
        name_en: "Manitoba",
        location_type: :subdivision1,
        country: country
      )

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-full-name", "Manitoba, Canada")
  end

  test "omits full name subtitle when equal to name_en", %{conn: conn} do
    location = insert(:country, name_en: "Solo")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-full-name")
  end

  test "shows breadcrumbs with link to all locations", %{conn: conn} do
    location = insert(:location, name_en: "Winnipeg")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a", "Locations")
  end

  test "shows ancestor locations in breadcrumbs", %{conn: conn} do
    parent = insert(:country, name_en: "Canada")

    child =
      insert(:location, name_en: "Manitoba", location_type: :subdivision1, country: parent)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{child.slug}")

    assert has_element?(show_live, "#location-breadcrumbs a", "Canada")
    assert has_element?(show_live, "#location-breadcrumbs span", "Manitoba")
  end

  test "shows stats with checklists count and lifelist link", %{conn: conn} do
    location = insert(:location, name_en: "Manitoba")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-stats")
    assert has_element?(show_live, "#lifelist-link", "Lifelist")
  end

  test "shows location type badge", %{conn: conn} do
    location = insert(:country, name_en: "Canada")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "span", "country")
  end

  test "lists direct children", %{conn: conn} do
    parent = insert(:country, name_en: "Canada")

    child1 =
      insert(:location, name_en: "Manitoba", location_type: :subdivision1, country: parent)

    child2 =
      insert(:location, name_en: "Ontario", location_type: :subdivision1, country: parent)

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
    special = insert(:special, name_en: "My Patch")
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
    location = insert(:country, name_en: "Canada")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-members")
  end

  test "shows members section with edit button for own special without members", %{
    conn: conn,
    user: user
  } do
    special = insert(:special, user_id: user.id)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{special.slug}")

    assert has_element?(show_live, "#location-members #edit-members-button")
    assert has_element?(show_live, "#no-members")
  end

  test "does not show add sub-location button for special and section locations", %{
    conn: conn,
    user: user
  } do
    special = insert(:special, user_id: user.id)
    section = insert(:location, location_type: :section, user_id: user.id)
    site = insert(:location, user_id: user.id)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{special.slug}")
    refute has_element?(show_live, "#add-sub-location-button")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{section.slug}")
    refute has_element?(show_live, "#add-sub-location-button")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{site.slug}")
    assert has_element?(show_live, "#add-sub-location-button")
  end

  test "does not show edit members button for non-special or unowned locations", %{
    conn: conn,
    user: user
  } do
    own_site = insert(:location, user_id: user.id)
    common_special = insert(:special)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{own_site.slug}")
    refute has_element?(show_live, "#edit-members-button")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{common_special.slug}")
    refute has_element?(show_live, "#edit-members-button")
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

  test "marks the header and details when location is disabled", %{conn: conn} do
    location = insert(:location, name_en: "Closed Spot", disabled: true)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "h1 span[title='Disabled']")
    assert has_element?(show_live, "#location-details span", "disabled")
  end

  test "does not mark an enabled location as disabled", %{conn: conn} do
    location = insert(:location, name_en: "Open Spot", disabled: false)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "h1 span[title='Disabled']")
    refute has_element?(show_live, "#location-details span", "disabled")
  end

  test "delete button enabled for empty location", %{conn: conn, user: user} do
    location = insert(:location, name_en: "Empty", user_id: user.id)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#delete-location-button[disabled]")
  end

  test "delete button disabled when location has children", %{conn: conn, user: user} do
    parent = insert(:country, name_en: "Canada", user_id: user.id)

    insert(:location,
      name_en: "Manitoba",
      location_type: :subdivision1,
      country: parent
    )

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{parent.slug}")

    assert has_element?(show_live, "#delete-location-button[disabled]")
  end

  test "delete button disabled when location has checklists", %{conn: conn, user: user} do
    location = insert(:location, name_en: "With Checklists", user_id: user.id)
    insert(:checklist, location: location)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#delete-location-button[disabled]")
  end

  test "edit and delete buttons hidden for a common location", %{conn: conn} do
    location = insert(:location, name_en: "Common Place")

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "a[href='/my/locations/#{location.slug}/edit']")
    refute has_element?(show_live, "#delete-location-button")
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

  test "renders a badge per special parent location", %{conn: conn} do
    five_mr = insert(:special, name_en: "5-Mile Radius")
    arabat = insert(:special, name_en: "Arabat Spit")
    location = insert(:location, name_en: "Home Patch")

    Kjogvi.Repo.insert_all("special_locations", [
      %{parent_location_id: five_mr.id, child_location_id: location.id},
      %{parent_location_id: arabat.id, child_location_id: location.id}
    ])

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#special-parent-badge-#{five_mr.id}", "5-Mile Radius")
    assert has_element?(show_live, "#special-parent-badge-#{arabat.id}", "Arabat Spit")
  end

  test "shows an import source note when import_source is present", %{conn: conn} do
    location = insert(:location, import_source: :legacy)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    assert has_element?(show_live, "#location-import-source", "Imported from: Legacy")
  end

  test "shows no import source note when import_source is nil", %{conn: conn} do
    location = insert(:location, import_source: nil)

    {:ok, show_live, _html} = live(conn, ~p"/my/locations/#{location.slug}")

    refute has_element?(show_live, "#location-import-source")
  end
end
