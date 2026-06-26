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

  test "renders a personal location nested under its common country", %{conn: conn, user: user} do
    country = insert(:country, name_en: "Canada")
    location = insert(:location, name_en: "Winnipeg", country: country, user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", country.name_en)
    assert has_element?(index_live, "a", location.name_en)
  end

  test "shows the user's own locations under the common scaffold but not another user's",
       %{conn: conn, user: user} do
    country = insert(:country, name_en: "Canada")
    own = insert(:location, name_en: "My Patch", country: country, user_id: user.id)

    other =
      insert(:location, name_en: "Their Patch", country: country, user_id: user_fixture().id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", country.name_en)
    assert has_element?(index_live, "a", own.name_en)
    refute has_element?(index_live, "a", other.name_en)
  end

  test "shows the user's own special location but not another user's", %{conn: conn, user: user} do
    own = insert(:special, name_en: "My List", user_id: user.id)

    other =
      insert(:special,
        name_en: "Their List",
        user_id: user_fixture().id
      )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "*", own.name_en)
    refute has_element?(index_live, "*", other.name_en)
  end

  test "a special location row links to its lifelist", %{conn: conn, user: user} do
    special = insert(:special, name_en: "My List", slug: "my-list", user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a[href='/my/lifelist/#{special.slug}']", "Lifelist")
  end

  test "a special location row shows its full name from ancestors", %{conn: conn, user: user} do
    country = insert(:country, name_en: "Canada")
    special = insert(:special, name_en: "My List", country: country, user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "*", "#{special.name_en}, #{country.name_en}")
  end

  test "counts only the user's own locations, not common ones", %{conn: conn, user: user} do
    country = insert(:country, name_en: "Canada")
    insert(:location, name_en: "My Patch", country: country, user_id: user.id)
    insert(:location, name_en: "My Other", country: country, user_id: user.id)
    # A common location the user can see but does not own — excluded from the count.
    insert(:location, name_en: "Shared", country: country)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "#own-locations-count", "2")
    assert has_element?(index_live, "span", "mine")
  end

  test "counts only the user's own specials", %{conn: conn, user: user} do
    insert(:special, name_en: "My List", user_id: user.id)
    insert(:special, name_en: "Shared List")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "#own-specials-count", "1")
  end

  test "the specials count links to the specials section", %{conn: conn, user: user} do
    insert(:special, name_en: "My List", user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a[href='#special-locations'] #own-specials-count")
    assert has_element?(index_live, "#special-locations")
  end

  test "shows lifelist badge for location with public_index", %{conn: conn, user: user} do
    insert(:location, name_en: "Local Park", public_index: 1, user_id: user.id)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "span", "lifelist filter")
  end

  test "does not show lifelist badge for location without public_index", %{conn: conn, user: user} do
    insert(:location, name_en: "Local Park", public_index: nil, user_id: user.id)

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
    country = insert(:country, name_en: "Canada")

    parent =
      insert(:location,
        name_en: "Winnipeg",
        location_type: "city",
        country: country,
        user_id: user.id
      )

    insert(:location,
      name_en: "My Patch",
      location_type: "site",
      country: country,
      city: parent,
      user_id: user.id
    )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    index_live
    |> element("button[phx-click='delete'][phx-value-id='#{parent.id}']")
    |> render_click()

    assert has_element?(index_live, "#location-delete-error-#{parent.id}", "sub-locations")
    refute is_nil(Kjogvi.Repo.get(Kjogvi.Geo.Location, parent.id))
  end

  test "deleting a location with checklists fails with an error and keeps it",
       %{conn: conn, user: user} do
    location =
      insert(:location, name_en: "With Checklists", location_type: "city", user_id: user.id)

    insert(:checklist, location: location)

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    index_live
    |> element("button[phx-click='delete'][phx-value-id='#{location.id}']")
    |> render_click()

    assert has_element?(index_live, "#location-delete-error-#{location.id}", "checklists")
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

    test "hides the specials section while searching", %{conn: conn, user: user} do
      insert(:special, name_en: "My List", user_id: user.id)

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      assert has_element?(index_live, "#special-locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "My"})

      refute has_element?(index_live, "#special-locations")
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

    test "a matching country renders with the common scaffold styling, like the tree",
         %{conn: conn} do
      country = insert(:country, name_en: "Canada", iso_code: "ca")

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      html =
        index_live
        |> element("#location-search")
        |> render_keyup(%{"value" => "Canada"})

      # The common node shows a flag and the type badge — the tree look, not the
      # old generic row.
      assert html =~ Kjogvi.Geo.Location.to_flag_emoji(country)
      assert has_element?(index_live, "span", "country")
    end

    test "a matching personal location keeps its edit and delete actions",
         %{conn: conn, user: user} do
      insert(:location, name_en: "Winnipeg", user_id: user.id)

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Winnipeg"})

      assert has_element?(index_live, "a[title='Edit']")
      assert has_element?(index_live, "button[title='Delete']")
    end

    test "a matching special location renders without edit or delete actions",
         %{conn: conn, user: user} do
      insert(:special, name_en: "My Big Year", user_id: user.id)

      {:ok, index_live, _html} = live(conn, ~p"/my/locations")

      index_live
      |> element("#location-search")
      |> render_keyup(%{"value" => "Big Year"})

      assert has_element?(index_live, "h2", "Search Results")
      refute has_element?(index_live, "button[title='Delete']")
    end
  end

  test "nests a personal location under its common country and subdivision", %{
    conn: conn,
    user: user
  } do
    country = insert(:country, name_en: "Germany")
    subdivision = insert(:subdivision1, name_en: "Bavaria", country: country)

    insert(:location,
      name_en: "Berlin",
      location_type: "site",
      country: country,
      subdivision1: subdivision,
      user_id: user.id
    )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", "Germany")
    assert has_element?(index_live, "a", "Bavaria")
    assert has_element?(index_live, "a", "Berlin")
  end

  test "subdivisions stay visible while their locations start collapsed", %{
    conn: conn,
    user: user
  } do
    country = insert(:country, name_en: "Germany")
    subdivision = insert(:subdivision1, name_en: "Bavaria", country: country)

    insert(:location,
      name_en: "Berlin",
      location_type: "site",
      country: country,
      subdivision1: subdivision,
      user_id: user.id
    )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    # The country body is expanded (no `hidden`), so its subdivisions show; the
    # subdivision body holding personal locations starts collapsed.
    assert has_element?(index_live, "#tree-body-#{country.id}:not(.hidden)")
    assert has_element?(index_live, "#tree-body-#{subdivision.id}.hidden")
    assert has_element?(index_live, "button[aria-controls='tree-body-#{subdivision.id}']")
  end

  test "a personal location with sub-locations gets its own collapsible toggle", %{
    conn: conn,
    user: user
  } do
    country = insert(:country, name_en: "Canada")
    subdivision = insert(:subdivision1, name_en: "Manitoba", country: country)

    city =
      insert(:location,
        name_en: "Winnipeg",
        location_type: "city",
        country: country,
        subdivision1: subdivision,
        user_id: user.id
      )

    insert(:location,
      name_en: "Assiniboine Park",
      location_type: "site",
      country: country,
      subdivision1: subdivision,
      city: city,
      user_id: user.id
    )

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    # The city is a personal location that is itself a parent, so it has a
    # collapsible body, hidden by default.
    assert has_element?(index_live, "#tree-body-#{city.id}.hidden")
    assert has_element?(index_live, "button[aria-controls='tree-body-#{city.id}']")
  end

  test "omits a common country the user has no locations under", %{conn: conn, user: user} do
    used = insert(:country, name_en: "Canada")
    insert(:location, name_en: "My Patch", country: used, user_id: user.id)

    _unused = insert(:country, name_en: "Mongolia")

    {:ok, index_live, _html} = live(conn, ~p"/my/locations")

    assert has_element?(index_live, "a", "Canada")
    refute has_element?(index_live, "a", "Mongolia")
  end

  test "shows a flag for a country with an ISO code", %{conn: conn, user: user} do
    country = insert(:country, name_en: "Canada", iso_code: "ca")
    insert(:location, name_en: "My Patch", country: country, user_id: user.id)

    {:ok, _index_live, html} = live(conn, ~p"/my/locations")

    assert html =~ Kjogvi.Geo.Location.to_flag_emoji(country)
  end

  test "shows the slug and type badge for a common country and subdivision", %{
    conn: conn,
    user: user
  } do
    country = insert(:country, name_en: "Canada", slug: "canada")
    subdivision = insert(:subdivision1, name_en: "Manitoba", slug: "manitoba", country: country)

    insert(:location,
      name_en: "My Patch",
      country: country,
      subdivision1: subdivision,
      user_id: user.id
    )

    {:ok, index_live, html} = live(conn, ~p"/my/locations")

    assert html =~ "canada"
    assert html =~ "manitoba"
    assert has_element?(index_live, "span", "country")
    assert has_element?(index_live, "span", "subdivision1")
  end
end
