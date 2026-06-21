defmodule Kjogvi.GeoTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo

  describe "cards_count/1" do
    test "returns 0 when no cards exist for the location" do
      location = insert(:location)

      assert Geo.cards_count(location.id) == 0
    end

    test "counts cards for the given location" do
      location = insert(:location)
      insert(:card, location: location)
      insert(:card, location: location)

      assert Geo.cards_count(location.id) == 2
    end

    test "does not count cards at other locations" do
      location = insert(:location)
      other_location = insert(:location)
      insert(:card, location: location)
      insert(:card, location: other_location)

      assert Geo.cards_count(location.id) == 1
    end
  end

  describe "children_count/1" do
    test "returns 0 when location has no children" do
      location = insert(:location)

      assert Geo.children_count(location.id) == 0
    end

    test "counts direct children" do
      parent = insert(:country)
      insert(:location, location_type: "subdivision1", country: parent)
      insert(:location, location_type: "subdivision2", country: parent)

      assert Geo.children_count(parent.id) == 2
    end

    test "counts nested descendants" do
      grandparent = insert(:country)

      parent =
        insert(:location, location_type: "subdivision1", country: grandparent)

      insert(:location,
        location_type: "city",
        country: grandparent,
        subdivision1_id: parent.id
      )

      assert Geo.children_count(grandparent.id) == 2
    end

    test "does not count unrelated locations" do
      location = insert(:country)
      insert(:country)

      assert Geo.children_count(location.id) == 0
    end
  end

  describe "direct_children/1" do
    test "returns direct children ordered by name, not deeper descendants" do
      country = insert(:country, name_en: "Canada")

      manitoba =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      _alberta =
        insert(:location,
          name_en: "Alberta",
          location_type: :subdivision1,
          country: country
        )

      _winnipeg =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: manitoba.id
        )

      children = Geo.direct_children(country)

      assert Enum.map(children, & &1.name_en) == ["Alberta", "Manitoba"]
    end
  end

  describe "ancestor_locations/1" do
    test "returns ancestors top to bottom from the level FKs" do
      country = insert(:country, name_en: "Canada")

      manitoba =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      winnipeg =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: manitoba.id
        )

      assert Geo.ancestor_locations(winnipeg) |> Enum.map(& &1.name_en) == ["Canada", "Manitoba"]
    end

    test "is empty for a top-level location" do
      country = insert(:country, name_en: "Canada")

      assert Geo.ancestor_locations(country) == []
    end
  end

  describe "get_logbook_settings_locations/0" do
    test "includes countries and subdivisions regardless of public_index" do
      country =
        insert(:country, name_en: "Poland", public_index: nil)

      subdivision =
        insert(:location,
          location_type: "subdivision1",
          name_en: "Pomerania",
          country: country,
          public_index: nil
        )

      result = Geo.get_logbook_settings_locations()
      ids = Enum.map(result, & &1.id)

      assert country.id in ids
      assert subdivision.id in ids
    end

    test "includes non-country/subdivision lifelist filters (e.g. a site)" do
      site =
        insert(:location, location_type: "site", name_en: "Backyard Patch", public_index: 1)

      result = Geo.get_logbook_settings_locations()
      assert site.id in Enum.map(result, & &1.id)
    end

    test "excludes sites and other non-lifelist-filter locations" do
      site = insert(:location, location_type: "site", name_en: "Backyard", public_index: nil)

      result = Geo.get_logbook_settings_locations()
      refute site.id in Enum.map(result, & &1.id)
    end

    test "does not duplicate a country that is also a lifelist filter" do
      country =
        insert(:country, name_en: "Canada", public_index: 1)

      result = Geo.get_logbook_settings_locations()
      assert Enum.count(result, &(&1.id == country.id)) == 1
    end
  end

  describe "get_lifelist_location_context/1" do
    test "World (nil) returns top-level locations as siblings and their children as children" do
      germany =
        insert(:country, name_en: "Germany", public_index: 1)

      bavaria =
        insert(:location,
          name_en: "Bavaria",
          location_type: :subdivision1,
          country: germany,
          public_index: 2
        )

      # Location without public_index should not appear
      insert(:country, name_en: "Hidden", public_index: nil)

      result = Geo.get_lifelist_location_context(nil)

      assert result.ancestors == []
      assert Enum.map(result.siblings, & &1.id) == [germany.id]
      assert Enum.map(result.children, & &1.id) == [bavaria.id]
    end

    test "specific location returns ancestors, siblings, and children" do
      germany =
        insert(:country, name_en: "Germany", public_index: 1)

      bavaria =
        insert(:location,
          name_en: "Bavaria",
          location_type: :subdivision1,
          country: germany,
          public_index: 2
        )

      hesse =
        insert(:location,
          name_en: "Hesse",
          location_type: :subdivision1,
          country: germany,
          public_index: 3
        )

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id,
          public_index: 4
        )

      result = Geo.get_lifelist_location_context(bavaria)

      assert Enum.map(result.ancestors, & &1.id) == [germany.id]
      assert Enum.map(result.siblings, & &1.id) == [hesse.id]
      assert Enum.map(result.children, & &1.id) == [munich.id]
    end

    test "deep location preserves ancestor order from the level FK chain" do
      germany =
        insert(:country, name_en: "Germany", public_index: 1)

      bavaria =
        insert(:location,
          name_en: "Bavaria",
          location_type: :subdivision1,
          country: germany,
          public_index: 2
        )

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id,
          public_index: 3
        )

      result = Geo.get_lifelist_location_context(munich)

      assert Enum.map(result.ancestors, & &1.id) == [germany.id, bavaria.id]
      assert result.siblings == []
      assert result.children == []
    end

    test "excludes locations without public_index" do
      germany =
        insert(:country, name_en: "Germany", public_index: 1)

      insert(:location,
        name_en: "Hidden Subdivision",
        location_type: :subdivision1,
        country: germany,
        public_index: nil
      )

      result = Geo.get_lifelist_location_context(germany)

      assert result.children == []
    end

    test "siblings are determined by effective lifelist parent, not exact ancestry" do
      ukraine =
        insert(:country, name_en: "Ukraine", public_index: 1)

      oblast =
        insert(:location,
          name_en: "Kyiv Oblast",
          location_type: :subdivision1,
          country: ukraine,
          public_index: 2
        )

      # district is a subdivision2 with no public_index — an intermediary
      district =
        insert(:location,
          name_en: "Brovary district",
          location_type: :subdivision2,
          country: ukraine,
          subdivision1_id: oblast.id,
          public_index: nil
        )

      kyiv =
        insert(:location,
          name_en: "Kyiv",
          location_type: :subdivision2,
          country: ukraine,
          subdivision1_id: oblast.id,
          public_index: 3
        )

      brovary =
        insert(:location,
          name_en: "Brovary",
          location_type: :city,
          country: ukraine,
          subdivision1_id: oblast.id,
          subdivision2_id: district.id,
          public_index: 4
        )

      # Both have effective lifelist parent = oblast, so they are siblings
      result = Geo.get_lifelist_location_context(kyiv)
      assert brovary.id in Enum.map(result.siblings, & &1.id)

      result2 = Geo.get_lifelist_location_context(brovary)
      assert kyiv.id in Enum.map(result2.siblings, & &1.id)
    end

    test "children are determined by nearest lifelist ancestor, skipping intermediaries" do
      germany =
        insert(:country, name_en: "Germany", public_index: 1)

      # subdivision with no public_index — an intermediary
      bavaria =
        insert(:location,
          name_en: "Bavaria",
          location_type: :subdivision1,
          country: germany,
          public_index: nil
        )

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id,
          public_index: 2
        )

      # Munich's nearest lifelist ancestor is Germany (Bavaria has no public_index)
      result = Geo.get_lifelist_location_context(germany)

      assert Enum.map(result.children, & &1.id) == [munich.id]

      # And from World view, Munich should still surface (its effective parent is Germany, a top-level sibling)
      world_result = Geo.get_lifelist_location_context(nil)
      assert Enum.map(world_result.children, & &1.id) == [munich.id]
    end
  end

  describe "get_countries/0" do
    test "returns only locations with country type" do
      canada = insert(:country, name_en: "Canada")
      insert(:location, location_type: "subdivision1", name_en: "Manitoba", country: canada)
      insert(:location, name_en: "Winnipeg", country: canada)

      countries = Geo.get_countries()
      assert length(countries) == 1
      assert hd(countries).name_en == "Canada"
    end

    test "returns only the country a sub-location hangs off" do
      country = shared_country()
      insert(:location, location_type: "subdivision1")

      assert [returned] = Geo.get_countries()
      assert returned.id == country.id
    end
  end

  describe "get_specials/1" do
    test "returns only special locations" do
      insert(:special, name_en: "5MR")
      insert(:country, name_en: "Canada")

      specials = Geo.get_specials(%Kjogvi.Scope{area: :admin})
      assert length(specials) == 1
      assert hd(specials).name_en == "5MR"
    end

    test "returns empty list when no specials exist" do
      insert(:country)

      assert Geo.get_specials(%Kjogvi.Scope{area: :admin}) == []
    end

    test "with a private scope, returns own and common specials but not another user's" do
      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :private}

      own = insert(:special, user_id: user.id)
      common = insert(:special)
      _other = insert(:special, user_id: user_fixture().id)

      ids = Geo.get_specials(scope) |> Enum.map(& &1.id) |> Enum.sort()
      assert ids == Enum.sort([own.id, common.id])
    end
  end

  describe "location_by_slug/1" do
    test "returns location matching the slug" do
      location = insert(:location, slug: "winnipeg-main")

      result = Geo.location_by_slug("winnipeg-main")
      assert result.id == location.id
    end

    test "returns nil for non-existent slug" do
      assert Geo.location_by_slug("nonexistent") == nil
    end
  end

  describe "location_by_slug_scope/2" do
    test "returns public location for anonymous scope" do
      location = insert(:location, slug: "public-loc", is_private: false)
      scope = %Kjogvi.Scope{current_user: nil, area: :community}

      result = Geo.location_by_slug_scope(scope, "public-loc")
      assert result.id == location.id
    end

    test "does not return private location for anonymous scope" do
      insert(:location, slug: "private-loc", is_private: true)
      scope = %Kjogvi.Scope{current_user: nil, area: :community}

      assert Geo.location_by_slug_scope(scope, "private-loc") == nil
    end

    test "returns private location for authenticated scope with private_view" do
      location = insert(:location, slug: "private-loc", is_private: true)

      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :private}

      result = Geo.location_by_slug_scope(scope, "private-loc")
      assert result.id == location.id
    end

    test "does not return private location for authenticated scope without private_view" do
      insert(:location, slug: "private-loc", is_private: true)

      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :community}

      assert Geo.location_by_slug_scope(scope, "private-loc") == nil
    end

    test "private-area user sees own and common locations but not another user's" do
      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :private}

      own = insert(:location, slug: "own-loc", location_type: "city", user_id: user.id)
      common = insert(:location, slug: "common-loc", location_type: "city")

      other =
        insert(:location, slug: "other-loc", location_type: "city", user_id: user_fixture().id)

      assert Geo.location_by_slug_scope(scope, "own-loc").id == own.id
      assert Geo.location_by_slug_scope(scope, "common-loc").id == common.id
      assert Geo.location_by_slug_scope(scope, "other-loc") == nil
      refute is_nil(other.id)
    end

    test "admin scope sees any user's location" do
      owned =
        insert(:location, slug: "owned-loc", location_type: "city", user_id: user_fixture().id)

      scope = %Kjogvi.Scope{current_user: user_fixture(), area: :admin}

      assert Geo.location_by_slug_scope(scope, "owned-loc").id == owned.id
    end
  end

  describe "search_locations/3" do
    test "private-area user finds own and common locations but not another user's" do
      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :private}

      own = insert(:location, slug: "own-park", name_en: "Park Own", user_id: user.id)
      common = insert(:location, slug: "common-park", name_en: "Park Common")

      _other =
        insert(:location, slug: "other-park", name_en: "Park Other", user_id: user_fixture().id)

      ids = Geo.search_locations(scope, "Park") |> Enum.map(& &1.id) |> Enum.sort()

      assert ids == Enum.sort([own.id, common.id])
    end

    test "admin scope finds any user's location" do
      scope = %Kjogvi.Scope{current_user: user_fixture(), area: :admin}

      owned =
        insert(:location, slug: "owned-park", name_en: "Park Owned", user_id: user_fixture().id)

      ids = Geo.search_locations(scope, "Park") |> Enum.map(& &1.id)

      assert owned.id in ids
    end
  end

  describe "get_locations/0" do
    test "returns all locations with card counts" do
      location = insert(:location)
      insert(:card, location: location)
      insert(:card, location: location)

      results = Geo.get_locations()
      loc = Enum.find(results, &(&1.id == location.id))
      assert loc.cards_count == 2
    end
  end

  describe "list_locations/1" do
    test "returns scoped non-special locations ordered by name with card counts" do
      scope = %Kjogvi.Scope{area: :admin}
      country = shared_country()
      insert(:location, name_en: "Zürich", location_type: "city", country: country)

      with_cards =
        insert(:location, name_en: "Aarau", location_type: "city", country: country)

      insert(:card, location: with_cards)

      result = Geo.list_locations(scope)

      # The two cities (the shared country they hang off is also listed),
      # ordered by name; the one with a card carries its count.
      cities = Enum.reject(result, &(&1.id == country.id))
      assert Enum.map(cities, & &1.name_en) == ["Aarau", "Zürich"]
      assert hd(cities).cards_count == 1
    end

    test "excludes special locations" do
      scope = %Kjogvi.Scope{area: :admin}
      insert(:special)
      country = insert(:country)

      ids = Geo.list_locations(scope) |> Enum.map(& &1.id)

      assert ids == [country.id]
    end

    test "with a private scope, excludes another user's locations" do
      user = user_fixture()
      scope = %Kjogvi.Scope{current_user: user, area: :private}

      own = insert(:location, location_type: "city", user_id: user.id)
      common = insert(:location, location_type: "city")
      other = insert(:location, location_type: "city", user_id: user_fixture().id)

      ids = Geo.list_locations(scope) |> Enum.map(& &1.id)

      assert own.id in ids
      assert common.id in ids
      refute other.id in ids
    end
  end

  describe "get_child_locations/1" do
    test "returns child locations with card counts" do
      parent = insert(:country)
      child = insert(:location, location_type: "subdivision1", country: parent)
      insert(:card, location: child)

      results = Geo.get_child_locations(parent.id)
      assert length(results) == 1
      assert hd(results).cards_count == 1
    end

    test "excludes special locations" do
      parent = insert(:country)
      insert(:special, country_id: parent.id)
      insert(:location, location_type: "subdivision1", country: parent)

      results = Geo.get_child_locations(parent.id)
      assert length(results) == 1
    end

    test "returns nested descendants" do
      country = insert(:country)
      subdivision = insert(:location, location_type: "subdivision1", country: country)

      insert(:location,
        location_type: "city",
        country: country,
        subdivision1_id: subdivision.id
      )

      results = Geo.get_child_locations(country.id)
      assert length(results) == 2
    end
  end

  describe "create_location/2 level FK derivation from parent" do
    setup do
      %{scope: %Kjogvi.Scope{current_user: user_fixture(), area: :private}}
    end

    test "derives the level FKs from the chosen parent", %{scope: scope} do
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country
        )

      {:ok, created} =
        Geo.create_location(scope, %{
          "slug" => "winnipeg",
          "name_en" => "Winnipeg",
          "is_private" => "false",
          "location_type" => "city",
          "parent_id" => subdivision1.id
        })

      assert created.country_id == country.id
      assert created.subdivision1_id == subdivision1.id
      assert created.city_id == nil
    end

    test "a top-level country has no level FKs", %{scope: scope} do
      {:ok, created} =
        Geo.create_location(scope, %{
          "slug" => "greenland",
          "name_en" => "Greenland",
          "is_private" => "false",
          "location_type" => "country"
        })

      assert created.country_id == nil
    end

    test "rejects a non-country location with no parent", %{scope: scope} do
      assert {:error, changeset} =
               Geo.create_location(scope, %{
                 "slug" => "floating-city",
                 "name_en" => "Floating City",
                 "is_private" => "false",
                 "location_type" => "city"
               })

      assert %{country_id: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "create_location/2 ownership" do
    setup do
      %{user: user, scope: scope} = scope_fixture()
      %{user: user, scope: scope}
    end

    test "stamps the creating user as the owner", %{user: user, scope: scope} do
      country = insert(:country, name_en: "Canada")

      # Non-country levels need a country parent to satisfy slot occupancy.
      for location_type <- ~w(country subdivision1 subdivision2 city site section special) do
        parent_id = if location_type == "country", do: nil, else: country.id

        {:ok, created} =
          Geo.create_location(scope, %{
            "slug" => "loc-#{location_type}",
            "name_en" => "Loc #{location_type}",
            "is_private" => "false",
            "location_type" => location_type,
            "parent_id" => parent_id
          })

        assert created.user_id == user.id
      end
    end
  end

  describe "update_location/3 and delete_location/2 authorization" do
    setup do
      %{user: owner, scope: owner_scope} = scope_fixture()
      %{user: _other, scope: other_scope} = scope_fixture()

      country = insert(:country, name_en: "Canada")

      location =
        insert(:location,
          location_type: :city,
          country: country,
          user_id: owner.id,
          slug: "owned-city"
        )

      %{
        owner_scope: owner_scope,
        other_scope: other_scope,
        location: location
      }
    end

    test "owner can update", %{owner_scope: scope, location: location} do
      assert {:ok, updated} =
               Geo.update_location(scope, location, %{"name_en" => "Renamed"})

      assert updated.name_en == "Renamed"
    end

    test "another user cannot update", %{other_scope: scope, location: location} do
      assert {:error, :forbidden} =
               Geo.update_location(scope, location, %{"name_en" => "Hijacked"})
    end

    test "owner can delete", %{owner_scope: scope, location: location} do
      assert {:ok, _} = Geo.delete_location(scope, location)
    end

    test "another user cannot delete", %{other_scope: scope, location: location} do
      assert {:error, :forbidden} = Geo.delete_location(scope, location)
    end
  end

  describe "update_location/3 with a location_type change" do
    setup do
      %{user: owner, scope: scope} = scope_fixture()
      country = insert(:country, name_en: "Canada")

      subdivision1 =
        insert(:location,
          name_en: "Manitoba",
          location_type: :subdivision1,
          country: country,
          user_id: owner.id,
          slug: "manitoba"
        )

      %{scope: scope, country: country, subdivision1: subdivision1}
    end

    test "cascades descendants' level FKs when the type moves", %{
      scope: scope,
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      site =
        insert(:location,
          name_en: "The Forks",
          location_type: :site,
          country: country,
          subdivision1_id: subdivision1.id,
          city_id: city.id
        )

      assert {:ok, updated} =
               Geo.update_location(scope, subdivision1, %{
                 "location_type" => "subdivision2",
                 "parent_id" => country.id
               })

      assert updated.location_type == :subdivision2

      reloaded_city = Repo.get!(Kjogvi.Geo.Location, city.id)
      assert reloaded_city.subdivision1_id == nil
      assert reloaded_city.subdivision2_id == subdivision1.id

      reloaded_site = Repo.get!(Kjogvi.Geo.Location, site.id)
      assert reloaded_site.subdivision1_id == nil
      assert reloaded_site.subdivision2_id == subdivision1.id
      assert reloaded_site.city_id == city.id
    end

    test "rejects a demotion that collides with an existing child", %{
      scope: scope,
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      assert {:error, changeset} =
               Geo.update_location(scope, subdivision1, %{
                 "location_type" => "city",
                 "parent_id" => country.id
               })

      assert %{location_type: [_]} = errors_on(changeset)

      # Nothing cascaded: the child is untouched.
      reloaded_city = Repo.get!(Kjogvi.Geo.Location, city.id)
      assert reloaded_city.subdivision1_id == subdivision1.id
      assert Repo.get!(Kjogvi.Geo.Location, subdivision1.id).location_type == :subdivision1
    end

    test "a same-type update does not touch descendants", %{
      scope: scope,
      country: country,
      subdivision1: subdivision1
    } do
      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision1_id: subdivision1.id
        )

      assert {:ok, _} =
               Geo.update_location(scope, subdivision1, %{
                 "name_en" => "Manitoba (renamed)",
                 "location_type" => "subdivision1",
                 "parent_id" => country.id
               })

      reloaded_city = Repo.get!(Kjogvi.Geo.Location, city.id)
      assert reloaded_city.subdivision1_id == subdivision1.id
      assert reloaded_city.subdivision2_id == nil
    end
  end

  defp scope_fixture do
    user = user_fixture()
    %{user: user, scope: %Kjogvi.Scope{current_user: user, area: :private}}
  end
end
