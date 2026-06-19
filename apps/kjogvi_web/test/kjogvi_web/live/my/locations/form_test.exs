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

  defp build_chain do
    country = insert(:location, name_en: "Canada", location_type: "country")

    region =
      insert(:location, name_en: "Manitoba", location_type: "region", ancestry: [country.id])

    city =
      insert(:location,
        name_en: "Winnipeg",
        location_type: "city",
        ancestry: [country.id, region.id]
      )

    %{country: country, region: region, city: city}
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
            is_private: "false"
          }
        )
        |> render_submit()
        |> follow_redirect(conn)

      loc = Geo.location_by_slug("greenland")
      assert loc.name_en == "Greenland"
      assert loc.ancestry == []
    end

    test "prefills parent and shows clear button when parent_id query param given", %{conn: conn} do
      parent = insert(:location, name_en: "Canada", location_type: "country")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{parent.id}")

      assert has_element?(view, "#location_parent_search")
      # The autocomplete shows its custom × button when a value is set.
      assert has_element?(view, "button[aria-label='Clear']")
    end

    test "leaves cached_parent empty when parent is a country", %{conn: conn} do
      country = insert(:location, name_en: "Canada", location_type: "country")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{country.id}")

      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"

      assert view |> element("#location_cached_subdivision_value span") |> render() =~
               ~r/>\s*<\/span>/

      assert render(view) =~ ~s|name="location[cached_parent_id]" value=""|
      assert render(view) =~ ~s|name="location[cached_city_id]" value=""|
    end

    test "leaves cached_parent empty when parent is a region", %{conn: conn} do
      %{region: region} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{region.id}")

      assert view |> element("#location_cached_subdivision_value") |> render() =~ "Manitoba"
      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"
      assert render(view) =~ ~s|name="location[cached_parent_id]" value=""|
      assert render(view) =~ ~s|name="location[cached_city_id]" value=""|
    end

    test "leaves cached_parent empty when parent is a city", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      assert render(view) =~ ~s|name="location[cached_city_id]" value="#{city.id}"|
      assert view |> element("#location_cached_subdivision_value") |> render() =~ "Manitoba"
      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"
      assert render(view) =~ ~s|name="location[cached_parent_id]" value=""|
    end

    test "sets cached_parent to direct parent when parent is a continent", %{conn: conn} do
      continent = insert(:location, name_en: "Europe", location_type: "continent")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{continent.id}")

      assert render(view) =~ ~s|name="location[cached_parent_id]" value="#{continent.id}"|

      assert view |> element("#location_cached_country_value span") |> render() =~
               ~r/>\s*<\/span>/

      assert view |> element("#location_cached_subdivision_value span") |> render() =~
               ~r/>\s*<\/span>/

      assert render(view) =~ ~s|name="location[cached_city_id]" value=""|
    end

    test "auto-fills cached_parent when parent has unclassified type", %{conn: conn} do
      %{country: country, region: region, city: city} = build_chain()

      yard =
        insert(:location,
          name_en: "My Yard",
          location_type: nil,
          ancestry: [country.id, region.id, city.id]
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{yard.id}")

      assert render(view) =~ ~s|name="location[cached_parent_id]" value="#{yard.id}"|
      assert render(view) =~ ~s|name="location[cached_city_id]" value="#{city.id}"|
      assert view |> element("#location_cached_subdivision_value") |> render() =~ "Manitoba"
      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"
    end
  end

  describe "cached_parent is direct parent only" do
    test "sets cached_parent to direct parent, not an unclassified ancestor", %{conn: conn} do
      country = insert(:location, name_en: "Canada", location_type: "country")

      yard =
        insert(:location, name_en: "My Yard", location_type: nil, ancestry: [country.id])

      feeder =
        insert(:location,
          name_en: "Feeder",
          location_type: "special",
          ancestry: [country.id, yard.id]
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{feeder.id}")

      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"
      assert render(view) =~ ~s|name="location[cached_parent_id]" value="#{feeder.id}"|
    end
  end

  describe "clear parent" do
    test "clears auto-filled cached_* fields and preserves user-typed fields", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "my-spot",
          name_en: "My Spot",
          iso_code: "ca",
          is_private: "true"
        }
      )
      |> render_change()

      # Click the × button inside the parent autocomplete to clear it.
      view
      |> element("#location_parent_search + button[aria-label='Clear']")
      |> render_click()

      html = render(view)

      assert html =~ ~s|name="location[parent_id]" value=""|
      assert html =~ ~s|name="location[cached_city_id]" value=""|

      assert view |> element("#location_cached_subdivision_value span") |> render() =~
               ~r/>\s*<\/span>/

      assert view |> element("#location_cached_country_value span") |> render() =~
               ~r/>\s*<\/span>/

      assert html =~ ~s|name="location[cached_parent_id]" value=""|

      slug_input = view |> element("#location_slug") |> render()
      name_input = view |> element("#location_name_en") |> render()
      iso_input = view |> element("#location_iso_code") |> render()

      assert slug_input =~ ~s|value="my-spot"|
      assert name_input =~ ~s|value="My Spot"|
      assert iso_input =~ ~s|value="ca"|
    end

    test "saving after clear persists with nil parent and cached_* fields", %{conn: conn} do
      %{city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "no-parent-spot",
          name_en: "No Parent Spot",
          iso_code: "",
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
      assert saved.parent_id == nil
      assert saved.cached_parent_id == nil
      assert saved.cached_city_id == nil
      assert saved.cached_subdivision_id == nil
      assert saved.cached_country_id == nil
    end

    test "manually changing cached_city autocomplete persists on save", %{conn: conn} do
      %{country: country, city: city} = build_chain()
      other_city = insert(:location, name_en: "Brandon", location_type: "city")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{country.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "manual-city-spot",
          name_en: "Manual City Spot"
        }
      )
      |> render_change()

      send(
        view.pid,
        {:autocomplete_select, "cached_selected",
         %{
           "field" => "cached_city",
           "result" => %{id: other_city.id, name_en: other_city.name_en}
         }}
      )

      _ = render(view)

      assert render(view) =~
               ~s|name="location[cached_city_id]" value="#{other_city.id}"|

      view
      |> form("#location-form")
      |> render_submit()

      saved = Geo.location_by_slug("manual-city-spot")
      assert saved
      assert saved.cached_city_id == other_city.id
      # Country is derived from ancestry, unaffected by cached_city change.
      assert saved.cached_country_id == country.id
      refute saved.cached_city_id == city.id
    end
  end

  describe "auto-derived cached country/subdivision on save" do
    test "saving with a parent populates cached_country and cached_subdivision", %{conn: conn} do
      %{country: country, region: region, city: city} = build_chain()

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      view
      |> form("#location-form",
        location: %{
          slug: "derived-spot",
          name_en: "Derived Spot",
          is_private: "false"
        }
      )
      |> render_submit()

      saved = Geo.location_by_slug("derived-spot")
      assert saved
      assert saved.cached_country_id == country.id
      assert saved.cached_subdivision_id == region.id
    end

    test "labels update live when parent is changed via autocomplete", %{conn: conn} do
      %{country: canada} = build_chain()
      france = insert(:location, name_en: "France", location_type: "country")

      {:ok, view, _html} = live(conn, ~p"/my/locations/new?parent_id=#{canada.id}")

      assert view |> element("#location_cached_country_value") |> render() =~ "Canada"

      send(
        view.pid,
        {:autocomplete_select, "parent_selected",
         %{"result" => %{id: france.id, name_en: "France"}}}
      )

      _ = render(view)

      assert view |> element("#location_cached_country_value") |> render() =~ "France"
    end
  end

  describe "parent selected preserves typed fields" do
    test "changing parent keeps user-typed slug/name/iso", %{conn: conn} do
      %{city: city} = build_chain()
      other_country = insert(:location, name_en: "France", location_type: "country")

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
        insert(:location,
          name_en: "Canada",
          location_type: "country",
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

    test "updates a location", %{conn: conn, user: user} do
      location =
        insert(:location,
          name_en: "Manitoba",
          slug: "mb",
          location_type: "city",
          user_id: user.id
        )

      {:ok, view, _html} = live(conn, ~p"/my/locations/#{location.slug}/edit")

      {:ok, _show, _html} =
        view
        |> form("#location-form",
          location: %{
            slug: "mb",
            name_en: "Manitoba (updated)",
            is_private: "false"
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

    test "redirects to the show page when editing a common location", %{conn: conn} do
      location = insert(:location, name_en: "Canada", slug: "ca", location_type: "country")

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
