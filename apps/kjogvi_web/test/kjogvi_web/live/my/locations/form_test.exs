defmodule KjogviWeb.Live.My.Locations.FormTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
  end

  # A country → subdivision1 → city chain wired with level FKs.
  defp build_chain do
    country = insert(:country, name_en: "Canada")

    subdivision1 =
      insert(:location,
        name_en: "Manitoba",
        location_type: :subdivision1,
        country: country
      )

    city =
      insert(:location,
        name_en: "Winnipeg",
        location_type: :city,
        country: country,
        subdivision1_id: subdivision1.id
      )

    %{country: country, subdivision1: subdivision1, city: city}
  end

  describe "new" do
    test "renders new location form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/locations/new")

      assert has_element?(view, "#location-form")
      assert has_element?(view, "#location-breadcrumbs a", "Locations")
    end

    test "creates a top-level country", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/my/locations/new")

      {:ok, _show, _html} =
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
        |> follow_redirect(conn)

      loc = Geo.location_by_slug("greenland")
      assert loc.name_en == "Greenland"
      assert loc.location_type == :country
      assert loc.country_id == nil
      assert loc.subdivision1_id == nil
    end

    test "prefills parent and shows clear button when parent_id query param given", %{conn: conn} do
      parent = insert(:country, name_en: "Canada")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{parent.id}")

      assert has_element?(view, "#location_parent_search")
      # The autocomplete shows its custom × button when a value is set.
      assert has_element?(view, "button[aria-label='Clear']")
    end

    test "shows the parent's ancestry summary when parent_id given", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      assert has_element?(view, "#location-ancestry-summary", "Winnipeg, Manitoba, Canada")
    end
  end

  describe "create derives level FKs from the chosen parent" do
    test "a site under a city inherits country/subdivision1 and slots the city", %{conn: conn} do
      %{country: country, subdivision1: subdivision1, city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "the-forks",
          name_en: "The Forks",
          location_type: "site",
          is_private: "false"
        }
      )
      |> render_submit()

      saved = Geo.location_by_slug("the-forks")
      assert saved
      assert saved.location_type == :site
      assert saved.country_id == country.id
      assert saved.subdivision1_id == subdivision1.id
      assert saved.city_id == city.id
      assert saved.site_id == nil
    end

    test "a city directly under a country inherits only country_id", %{conn: conn} do
      %{country: country} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{country.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "kyiv",
          name_en: "Kyiv",
          location_type: "city",
          is_private: "false"
        }
      )
      |> render_submit()

      saved = Geo.location_by_slug("kyiv")
      assert saved
      assert saved.country_id == country.id
      assert saved.subdivision1_id == nil
      assert saved.city_id == nil
    end

    test "rejects a parent at or below the new location's own level", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "another-city",
          name_en: "Another City",
          location_type: "city",
          is_private: "false"
        }
      )
      |> render_submit()

      # The city_id slot (the parent city) cannot be set for a city.
      assert has_element?(view, "#location-ancestry-errors", "cannot be set for a city")
      refute Geo.location_by_slug("another-city")
    end

    test "rejects a section parent and surfaces the error", %{conn: conn} do
      %{country: country} = build_chain()

      section =
        insert(:location, name_en: "Trail", location_type: :section, country: country)

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{section.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "nested-section",
          name_en: "Nested Section",
          location_type: "section",
          is_private: "false"
        }
      )
      |> render_submit()

      assert has_element?(view, "#location-ancestry-errors", "cannot be a section")
      refute Geo.location_by_slug("nested-section")
    end
  end

  describe "clear parent" do
    test "clears the derived level FKs and preserves user-typed fields", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "my-spot",
          name_en: "My Spot",
          location_type: "country",
          iso_code: "ca",
          is_private: "true"
        }
      )
      |> render_change()

      view
      |> element("#location_parent_search + button[aria-label='Clear']")
      |> render_click()

      html = render(view)

      assert html =~ ~s|name="location[parent_id]" value=""|
      refute has_element?(view, "#location-ancestry-summary")

      slug_input = view |> element("#location_slug") |> render()
      name_input = view |> element("#location_name_en") |> render()
      iso_input = view |> element("#location_iso_code") |> render()

      assert slug_input =~ ~s|value="my-spot"|
      assert name_input =~ ~s|value="My Spot"|
      assert iso_input =~ ~s|value="ca"|
    end

    test "saving after clear persists a top-level location with no level FKs", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "no-parent-spot",
          name_en: "No Parent Spot",
          location_type: "country",
          is_private: "false"
        }
      )
      |> render_change()

      view
      |> element("#location_parent_search + button[aria-label='Clear']")
      |> render_click()

      view
      |> form("#location-form")
      |> render_submit()

      saved = Geo.location_by_slug("no-parent-spot")
      assert saved
      assert saved.country_id == nil
      assert saved.subdivision1_id == nil
      assert saved.subdivision2_id == nil
      assert saved.city_id == nil
      assert saved.site_id == nil
    end
  end

  describe "parent selected via autocomplete" do
    test "updates the ancestry summary and re-derives FKs on save", %{conn: conn} do
      %{country: canada} = build_chain()
      france = insert(:country, name_en: "France")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{canada.id}")

      assert has_element?(view, "#location-ancestry-summary", "Canada")

      send(
        view.pid,
        {:autocomplete_select, "parent_selected",
         %{"result" => %{id: france.id, name_en: "France"}}}
      )

      _ = render(view)

      assert has_element?(view, "#location-ancestry-summary", "France")

      view
      |> form("#location-form",
        location: %{slug: "paris", name_en: "Paris", location_type: "city", is_private: "false"}
      )
      |> render_submit()

      saved = Geo.location_by_slug("paris")
      assert saved.country_id == france.id
    end

    test "changing parent keeps user-typed slug/name/iso", %{conn: conn} do
      %{city: city} = build_chain()
      other_country = insert(:country, name_en: "France")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "my-spot",
          name_en: "My Spot",
          iso_code: "fr",
          is_private: "false"
        }
      )
      |> render_change()

      send(
        view.pid,
        {:autocomplete_select, "parent_selected",
         %{"result" => %{id: other_country.id, name_en: "France"}}}
      )

      _ = render(view)

      slug_input = view |> element("#location_slug") |> render()
      name_input = view |> element("#location_name_en") |> render()
      iso_input = view |> element("#location_iso_code") |> render()

      assert slug_input =~ ~s|value="my-spot"|
      assert name_input =~ ~s|value="My Spot"|
      assert iso_input =~ ~s|value="fr"|
    end
  end

  describe "map picker" do
    test "renders map container with current coords as data attributes", %{conn: conn, user: user} do
      location =
        insert(:location,
          name_en: "Winnipeg",
          slug: "wpg",
          lat: Decimal.new("49.89510"),
          lon: Decimal.new("-97.13840"),
          user_id: user.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      assert has_element?(view, "#location-map-picker")

      picker_html = view |> element("#location-map-picker") |> render()
      assert picker_html =~ ~s|data-lat="49.89510"|
      assert picker_html =~ ~s|data-lon="-97.13840"|
    end

    test "renders parent coords as data attributes when no coords set", %{conn: conn} do
      parent =
        insert(:country,
          name_en: "Canada",
          lat: Decimal.new("56.13040"),
          lon: Decimal.new("-106.34680")
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{parent.id}")

      picker_html = view |> element("#location-map-picker") |> render()
      assert picker_html =~ ~s|data-parent-lat="56.13040"|
      assert picker_html =~ ~s|data-parent-lon="-106.34680"|
    end

    test "map_picked event updates form lat/lon", %{conn: conn, user: user} do
      location = insert(:location, name_en: "Manitoba", slug: "mb", user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      render_hook(view, "map_picked", %{"lat" => "49.895100", "lon" => "-97.138400"})

      lat_input = view |> element("#location_lat") |> render()
      lon_input = view |> element("#location_lon") |> render()
      assert lat_input =~ ~s|value="49.895100"|
      assert lon_input =~ ~s|value="-97.138400"|
    end

    test "map_cleared event clears lat/lon", %{conn: conn, user: user} do
      location =
        insert(:location,
          name_en: "Winnipeg",
          slug: "wpg",
          lat: Decimal.new("49.89510"),
          lon: Decimal.new("-97.13840"),
          user_id: user.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      render_click(view, "map_cleared")

      lat_input = view |> element("#location_lat") |> render()
      refute lat_input =~ ~s|value="|
    end
  end

  describe "edit" do
    test "renders edit form with current values", %{conn: conn, user: user} do
      location = insert(:location, name_en: "Manitoba", slug: "mb", user_id: user.id)

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      assert has_element?(view, "#location-form")
      assert has_element?(view, "#location-breadcrumbs a", "Manitoba")
    end

    test "prefills the parent from the location's level FKs", %{conn: conn, user: user} do
      country = insert(:country, name_en: "Canada")

      location =
        insert(:location,
          name_en: "Manitoba",
          slug: "mb",
          location_type: :subdivision1,
          country: country,
          user_id: user.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      assert has_element?(view, "#location-ancestry-summary", "Canada")
      assert render(view) =~ ~s|name="location[parent_id]" value="#{country.id}"|
    end

    test "updates a location without touching its ancestry", %{conn: conn, user: user} do
      country = insert(:country, name_en: "Canada")

      location =
        insert(:location,
          name_en: "Winnipeg",
          slug: "wpg",
          location_type: :city,
          country: country,
          user_id: user.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      {:ok, _show, _html} =
        view
        |> form("#location-form",
          location: %{
            slug: "wpg",
            name_en: "Winnipeg (updated)",
            location_type: "city",
            is_private: "false"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      updated = Repo.get(Location, location.id)
      assert updated.name_en == "Winnipeg (updated)"
      assert updated.country_id == country.id
    end

    test "changing location_type cascades the descendants' level FKs", %{conn: conn, user: user} do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          slug: "mb",
          location_type: :subdivision1,
          country: country,
          user_id: user.id
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{subdivision1.slug}/edit")

      {:ok, _show, _html} =
        view
        |> form("#location-form",
          location: %{
            slug: "mb",
            name_en: "Manitoba",
            location_type: "subdivision2",
            is_private: "false"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      assert Repo.get(Location, subdivision1.id).location_type == :subdivision2

      reloaded_city = Repo.get(Location, city.id)
      assert reloaded_city.subdivision1_id == nil
      assert reloaded_city.subdivision2_id == subdivision1.id
    end

    test "rejects a location_type change that collides with a child", %{conn: conn, user: user} do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          slug: "mb",
          location_type: :subdivision1,
          country: country,
          user_id: user.id
        )

      insert(:location,
        name_en: "Winnipeg",
        location_type: :city,
        country: country,
        subdivision1_id: subdivision1.id
      )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{subdivision1.slug}/edit")

      view
      |> form("#location-form",
        location: %{
          slug: "mb",
          name_en: "Manitoba",
          location_type: "city",
          is_private: "false"
        }
      )
      |> render_submit()

      assert has_element?(view, "#location-type-errors", "sub-location is at that level or above")
      assert Repo.get(Location, subdivision1.id).location_type == :subdivision1
    end

    test "redirects for nonexistent slug", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/my/locations"}}} =
               live(conn, ~p"/my/locations/nonexistent/edit")
    end

    test "redirects to the show page when editing a common location", %{conn: conn} do
      location = insert(:country, name_en: "Canada", slug: "ca")

      assert {:error, {:live_redirect, %{to: "/my/locations/ca"}}} =
               live(conn, ~p"/my/locations/#{location.slug}/edit")
    end

    test "redirects when editing another user's location", %{conn: conn} do
      location =
        insert(:location, name_en: "Their Patch", slug: "theirs", user_id: user_fixture().id)

      # Another user's location is not visible to this scope, so it reads as "not found".
      assert {:error, {:live_redirect, %{to: "/my/locations"}}} =
               live(conn, ~p"/my/locations/#{location.slug}/edit")
    end
  end
end
