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
            is_private: "false",
            is_patch: "false"
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
      assert has_element?(view, "button[phx-click='clear_parent']")
    end

    test "leaves cached_parent empty when parent is a country", %{conn: conn} do
      country = insert(:location, name_en: "Canada", location_type: "country")

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{country.id}")

      assert html =~ ~s|name="location[cached_country_id]" value="#{country.id}"|
      assert html =~ ~s|name="location[cached_parent_id]" value=""|
      assert html =~ ~s|name="location[cached_city_id]" value=""|
      assert html =~ ~s|name="location[cached_subdivision_id]" value=""|
    end

    test "leaves cached_parent empty when parent is a region", %{conn: conn} do
      %{country: country, region: region} = build_chain()

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{region.id}")

      assert html =~ ~s|name="location[cached_subdivision_id]" value="#{region.id}"|
      assert html =~ ~s|name="location[cached_country_id]" value="#{country.id}"|
      assert html =~ ~s|name="location[cached_parent_id]" value=""|
      assert html =~ ~s|name="location[cached_city_id]" value=""|
    end

    test "leaves cached_parent empty when parent is a city", %{conn: conn} do
      %{country: country, region: region, city: city} = build_chain()

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{city.id}")

      assert html =~ ~s|name="location[cached_city_id]" value="#{city.id}"|
      assert html =~ ~s|name="location[cached_subdivision_id]" value="#{region.id}"|
      assert html =~ ~s|name="location[cached_country_id]" value="#{country.id}"|
      assert html =~ ~s|name="location[cached_parent_id]" value=""|
    end

    test "sets cached_parent to direct parent when parent is a continent", %{conn: conn} do
      continent = insert(:location, name_en: "Europe", location_type: "continent")

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{continent.id}")

      assert html =~ ~s|name="location[cached_parent_id]" value="#{continent.id}"|
      assert html =~ ~s|name="location[cached_country_id]" value=""|
      assert html =~ ~s|name="location[cached_city_id]" value=""|
      assert html =~ ~s|name="location[cached_subdivision_id]" value=""|
    end

    test "auto-fills cached_parent when parent has unclassified type", %{conn: conn} do
      %{country: country, region: region, city: city} = build_chain()

      yard =
        insert(:location,
          name_en: "My Yard",
          location_type: nil,
          ancestry: [country.id, region.id, city.id]
        )

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{yard.id}")

      assert html =~ ~s|name="location[cached_parent_id]" value="#{yard.id}"|
      assert html =~ ~s|name="location[cached_city_id]" value="#{city.id}"|
      assert html =~ ~s|name="location[cached_subdivision_id]" value="#{region.id}"|
      assert html =~ ~s|name="location[cached_country_id]" value="#{country.id}"|
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

      {:ok, _view, html} = live(conn, ~p"/my/locations/new?parent_id=#{feeder.id}")

      assert html =~ ~s|name="location[cached_country_id]" value="#{country.id}"|
      assert html =~ ~s|name="location[cached_parent_id]" value="#{feeder.id}"|
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
          is_private: "true",
          is_patch: "false"
        }
      )
      |> render_change()

      html = render_click(view, "clear_parent")

      assert html =~ ~s|name="location[parent_id]" value=""|
      assert html =~ ~s|name="location[cached_city_id]" value=""|
      assert html =~ ~s|name="location[cached_subdivision_id]" value=""|
      assert html =~ ~s|name="location[cached_country_id]" value=""|
      assert html =~ ~s|name="location[cached_parent_id]" value=""|

      slug_input = view |> element("#location_slug") |> render()
      name_input = view |> element("#location_name_en") |> render()
      iso_input = view |> element("#location_iso_code") |> render()

      assert slug_input =~ ~s|value="my-spot"|
      assert name_input =~ ~s|value="My Spot"|
      assert iso_input =~ ~s|value="ca"|
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
          is_private: "false",
          is_patch: "false"
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
            is_patch: "false"
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
end
