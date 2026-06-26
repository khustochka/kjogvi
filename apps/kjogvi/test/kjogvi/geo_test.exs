defmodule Kjogvi.GeoTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo

  describe "checklists_count/1" do
    test "returns 0 when no checklists exist for the location" do
      location = insert(:location)

      assert Geo.checklists_count(location.id) == 0
    end

    test "counts checklists for the given location" do
      location = insert(:location)
      insert(:checklist, location: location)
      insert(:checklist, location: location)

      assert Geo.checklists_count(location.id) == 2
    end

    test "does not count checklists at other locations" do
      location = insert(:location)
      other_location = insert(:location)
      insert(:checklist, location: location)
      insert(:checklist, location: other_location)

      assert Geo.checklists_count(location.id) == 1
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

  describe "get_lifelist_location_context/2" do
    test "World (nil) lists countries as siblings and no children" do
      germany = insert(:country, name_en: "Germany")

      bavaria =
        insert(:location, name_en: "Bavaria", location_type: :subdivision1, country: germany)

      # A location outside the passed universe should not appear.
      insert(:country, name_en: "Hidden")

      result = Geo.get_lifelist_location_context([germany, bavaria], nil)

      assert result.ancestors == []
      assert Enum.map(result.siblings, & &1.id) == [germany.id]
      # Subdivisions surface only once their country is selected.
      assert result.children == []
    end

    test "orders siblings by name" do
      germany = insert(:country, name_en: "Germany")
      austria = insert(:country, name_en: "Austria")

      result = Geo.get_lifelist_location_context([germany, austria], nil)

      assert Enum.map(result.siblings, & &1.name_en) == ["Austria", "Germany"]
    end

    test "selecting a country lists its subdivisions as children, ordered by name" do
      germany = insert(:country, name_en: "Germany")

      hesse =
        insert(:location, name_en: "Hesse", location_type: :subdivision1, country: germany)

      bavaria =
        insert(:location, name_en: "Bavaria", location_type: :subdivision1, country: germany)

      result = Geo.get_lifelist_location_context([germany, hesse, bavaria], germany)

      assert Enum.map(result.children, & &1.name_en) == ["Bavaria", "Hesse"]
    end

    test "specific location returns ancestors, siblings, and children" do
      germany = insert(:country, name_en: "Germany")

      bavaria =
        insert(:location, name_en: "Bavaria", location_type: :subdivision1, country: germany)

      hesse =
        insert(:location, name_en: "Hesse", location_type: :subdivision1, country: germany)

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id
        )

      result = Geo.get_lifelist_location_context([germany, bavaria, hesse, munich], bavaria)

      assert Enum.map(result.ancestors, & &1.id) == [germany.id]
      assert Enum.map(result.siblings, & &1.id) == [hesse.id]
      assert Enum.map(result.children, & &1.id) == [munich.id]
    end

    test "deep location preserves ancestor order from the level FK chain" do
      germany = insert(:country, name_en: "Germany")

      bavaria =
        insert(:location, name_en: "Bavaria", location_type: :subdivision1, country: germany)

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id
        )

      result = Geo.get_lifelist_location_context([germany, bavaria, munich], munich)

      assert Enum.map(result.ancestors, & &1.id) == [germany.id, bavaria.id]
      assert result.siblings == []
      assert result.children == []
    end

    test "excludes locations outside the passed universe" do
      germany = insert(:country, name_en: "Germany")

      hidden =
        insert(:location,
          name_en: "Hidden Subdivision",
          location_type: :subdivision1,
          country: germany
        )

      result = Geo.get_lifelist_location_context([germany], germany)

      assert hidden.id not in Enum.map(result.children, & &1.id)
      assert result.children == []
    end

    test "siblings are determined by effective filter parent, not exact ancestry" do
      ukraine = insert(:country, name_en: "Ukraine")

      oblast =
        insert(:location, name_en: "Kyiv Oblast", location_type: :subdivision1, country: ukraine)

      # district is a subdivision2 outside the universe — an intermediary
      district =
        insert(:location,
          name_en: "Brovary district",
          location_type: :subdivision2,
          country: ukraine,
          subdivision1_id: oblast.id
        )

      kyiv =
        insert(:location,
          name_en: "Kyiv",
          location_type: :subdivision2,
          country: ukraine,
          subdivision1_id: oblast.id
        )

      brovary =
        insert(:location,
          name_en: "Brovary",
          location_type: :city,
          country: ukraine,
          subdivision1_id: oblast.id,
          subdivision2_id: district.id
        )

      universe = [ukraine, oblast, kyiv, brovary]

      # Both have effective filter parent = oblast, so they are siblings.
      result = Geo.get_lifelist_location_context(universe, kyiv)
      assert brovary.id in Enum.map(result.siblings, & &1.id)

      result2 = Geo.get_lifelist_location_context(universe, brovary)
      assert kyiv.id in Enum.map(result2.siblings, & &1.id)
    end

    test "children are determined by nearest filter ancestor, skipping intermediaries" do
      germany = insert(:country, name_en: "Germany")

      # subdivision outside the universe — an intermediary
      bavaria =
        insert(:location, name_en: "Bavaria", location_type: :subdivision1, country: germany)

      munich =
        insert(:location,
          name_en: "Munich",
          location_type: :subdivision2,
          country: germany,
          subdivision1_id: bavaria.id
        )

      universe = [germany, munich]

      # Munich's nearest filter ancestor is Germany (Bavaria is not in the universe).
      result = Geo.get_lifelist_location_context(universe, germany)

      assert Enum.map(result.children, & &1.id) == [munich.id]

      # World shows only top-level siblings, never their children.
      world_result = Geo.get_lifelist_location_context(universe, nil)
      assert world_result.children == []
      assert Enum.map(world_result.siblings, & &1.id) == [germany.id]
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

    test "preloads level ancestors so long_name resolves" do
      country = insert(:country, name_en: "Canada")
      insert(:special, name_en: "5MR", country: country)

      [special] = Geo.get_specials(%Kjogvi.Scope{area: :admin})

      assert Kjogvi.Geo.Location.long_name(:private, special) == "5MR, Canada"
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

  describe "location_tree/1" do
    setup do
      user = user_fixture()
      %{user: user, scope: %Kjogvi.Scope{current_user: user, area: :private}}
    end

    # Finds the child node for `location` among a node list.
    defp child_node(nodes, location) do
      Enum.find(nodes, &(&1.location.id == location.id))
    end

    test "nests each location under its direct parent", %{user: user, scope: scope} do
      country = insert(:country, name_en: "Canada")
      subdivision = insert(:subdivision1, name_en: "Manitoba", country: country)

      site =
        insert(:location,
          name_en: "My Patch",
          country: country,
          subdivision1: subdivision,
          user_id: user.id
        )

      [country_node] = Geo.location_tree(scope)
      assert country_node.location.id == country.id

      subdivision_node = child_node(country_node.children, subdivision)
      assert subdivision_node

      site_node = child_node(subdivision_node.children, site)
      assert site_node
      assert site_node.children == []
    end

    test "builds the full hierarchy to any depth, each node holding only its direct children",
         %{user: user, scope: scope} do
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

      site =
        insert(:location,
          name_en: "Assiniboine Park",
          location_type: "site",
          country: country,
          subdivision1: subdivision,
          city: city,
          user_id: user.id
        )

      [country_node] = Geo.location_tree(scope)
      subdivision_node = child_node(country_node.children, subdivision)

      # The subdivision's direct child is the city, not the deeper site.
      assert Enum.map(subdivision_node.children, & &1.location.id) == [city.id]

      city_node = child_node(subdivision_node.children, city)
      assert Enum.map(city_node.children, & &1.location.id) == [site.id]
    end

    test "places a location with a skipped level under its deepest common ancestor", %{
      user: user,
      scope: scope
    } do
      country = insert(:country, name_en: "Germany")
      subdivision = insert(:subdivision1, name_en: "Bavaria", country: country)

      # A site directly under the subdivision (no city in between).
      site =
        insert(:location,
          name_en: "Berlin",
          location_type: "site",
          country: country,
          subdivision1: subdivision,
          user_id: user.id
        )

      [country_node] = Geo.location_tree(scope)
      subdivision_node = child_node(country_node.children, subdivision)
      assert Enum.map(subdivision_node.children, & &1.location.id) == [site.id]
    end

    test "places a location with no subdivision directly under the country", %{
      user: user,
      scope: scope
    } do
      country = insert(:country, name_en: "Germany")
      site = insert(:location, name_en: "Berlin", country: country, user_id: user.id)

      [country_node] = Geo.location_tree(scope)
      assert Enum.map(country_node.children, & &1.location.id) == [site.id]
    end

    test "excludes common countries and subdivisions with no personal descendants", %{
      scope: scope,
      user: user
    } do
      used = insert(:country, name_en: "Used")
      _used_site = insert(:location, country: used, user_id: user.id)

      _unused_country = insert(:country, name_en: "Unused")
      _unused_subdivision = insert(:subdivision1, name_en: "Empty", country: used)

      [country_node] = Geo.location_tree(scope)
      assert country_node.location.id == used.id
      # The empty subdivision is not pulled in.
      assert Enum.all?(country_node.children, &(&1.location.location_type != :subdivision1))
    end

    test "excludes specials", %{scope: scope, user: user} do
      _special = insert(:special, user_id: user.id)

      assert Geo.location_tree(scope) == []
    end

    test "does not include another user's locations", %{scope: scope, user: user} do
      country = insert(:country, name_en: "Canada")
      own = insert(:location, name_en: "Mine", country: country, user_id: user.id)
      _other = insert(:location, name_en: "Theirs", country: country, user_id: user_fixture().id)

      [country_node] = Geo.location_tree(scope)
      assert Enum.map(country_node.children, & &1.location.id) == [own.id]
    end

    test "orders each level by name", %{user: user, scope: scope} do
      country_b = insert(:country, name_en: "Brazil")
      country_a = insert(:country, name_en: "Argentina")
      sub_z = insert(:subdivision1, name_en: "Zulia", country: country_a)
      sub_a = insert(:subdivision1, name_en: "Aragua", country: country_a)

      insert(:location,
        name_en: "B site",
        country: country_a,
        subdivision1: sub_a,
        user_id: user.id
      )

      insert(:location,
        name_en: "A site",
        country: country_a,
        subdivision1: sub_a,
        user_id: user.id
      )

      insert(:location, country: country_a, subdivision1: sub_z, user_id: user.id)
      insert(:location, country: country_b, user_id: user.id)

      tree = Geo.location_tree(scope)
      assert Enum.map(tree, & &1.location.name_en) == ["Argentina", "Brazil"]

      argentina = hd(tree)
      assert Enum.map(argentina.children, & &1.location.name_en) == ["Aragua", "Zulia"]

      aragua = child_node(argentina.children, sub_a)
      assert Enum.map(aragua.children, & &1.location.name_en) == ["A site", "B site"]
    end

    test "orders direct children by hierarchy rank, then name", %{user: user, scope: scope} do
      country = insert(:country, name_en: "Canada")
      subdivision = insert(:subdivision1, name_en: "Manitoba", country: country)

      # Names chosen so alphabetical order (Aaa site, Mmm county, Zzz city) differs
      # from hierarchy order (subdivision2, city, site).
      site =
        insert(:location,
          name_en: "Aaa Site",
          location_type: "site",
          country: country,
          subdivision1: subdivision,
          user_id: user.id
        )

      county =
        insert(:location,
          name_en: "Mmm County",
          location_type: "subdivision2",
          country: country,
          subdivision1: subdivision,
          user_id: user.id
        )

      city =
        insert(:location,
          name_en: "Zzz City",
          location_type: "city",
          country: country,
          subdivision1: subdivision,
          user_id: user.id
        )

      [country_node] = Geo.location_tree(scope)
      subdivision_node = child_node(country_node.children, subdivision)

      assert Enum.map(subdivision_node.children, & &1.location.id) == [
               county.id,
               city.id,
               site.id
             ]
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

    test "includes specials by default" do
      scope = %Kjogvi.Scope{current_user: user_fixture(), area: :admin}
      special = insert(:special, name_en: "Park Special")

      ids = Geo.search_locations(scope, "Park") |> Enum.map(& &1.id)

      assert special.id in ids
    end

    test "checklist-input filter excludes specials" do
      scope = %Kjogvi.Scope{current_user: user_fixture(), area: :admin}
      regular = insert(:location, slug: "park-site", name_en: "Park Site")
      special = insert(:special, name_en: "Park Special")

      ids =
        Geo.search_locations(scope, "Park", filter: Geo.Location.Filter.for_checklist_input())
        |> Enum.map(& &1.id)

      assert regular.id in ids
      refute special.id in ids
    end

    test "parent-pick filter excludes specials and sections" do
      scope = %Kjogvi.Scope{current_user: user_fixture(), area: :admin}
      city = insert(:location, slug: "park-city", name_en: "Park City", location_type: :city)
      special = insert(:special, name_en: "Park Special")

      section =
        insert(:location, slug: "park-section", name_en: "Park Section", location_type: :section)

      ids =
        Geo.search_locations(scope, "Park", filter: Geo.Location.Filter.for_parent_pick())
        |> Enum.map(& &1.id)

      assert city.id in ids
      refute special.id in ids
      refute section.id in ids
    end
  end

  describe "get_locations/0" do
    test "returns all locations with checklist counts" do
      location = insert(:location)
      insert(:checklist, location: location)
      insert(:checklist, location: location)

      results = Geo.get_locations()
      loc = Enum.find(results, &(&1.id == location.id))
      assert loc.checklists_count == 2
    end
  end

  describe "list_locations/1" do
    test "returns scoped non-special locations ordered by name with checklist counts" do
      scope = %Kjogvi.Scope{area: :admin}
      country = shared_country()
      insert(:location, name_en: "Zürich", location_type: "city", country: country)

      with_checklists =
        insert(:location, name_en: "Aarau", location_type: "city", country: country)

      insert(:checklist, location: with_checklists)

      result = Geo.list_locations(scope)

      # The two cities (the shared country they hang off is also listed),
      # ordered by name; the one with a checklist carries its count.
      cities = Enum.reject(result, &(&1.id == country.id))
      assert Enum.map(cities, & &1.name_en) == ["Aarau", "Zürich"]
      assert hd(cities).checklists_count == 1
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
    test "returns child locations with checklist counts" do
      parent = insert(:country)
      child = insert(:location, location_type: "subdivision1", country: parent)
      insert(:checklist, location: child)

      results = Geo.get_child_locations(parent.id)
      assert length(results) == 1
      assert hd(results).checklists_count == 1
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

    test "rejects a country: a user may not create a common-only type", %{scope: scope} do
      assert {:error, changeset} =
               Geo.create_location(scope, %{
                 "slug" => "greenland",
                 "name_en" => "Greenland",
                 "is_private" => "false",
                 "location_type" => "country"
               })

      assert %{location_type: ["can't be country for a user location"]} = errors_on(changeset)
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

      # `country`/`subdivision1` are common-only and can't be user-owned, so a
      # user's locations span the assignable types below them (all need a country
      # parent to satisfy slot occupancy).
      for location_type <- ~w(subdivision2 city site section special) do
        parent_id = country.id

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

    test "rejects a subdivision1 for a user", %{scope: scope} do
      country = insert(:country, name_en: "Canada")

      assert {:error, changeset} =
               Geo.create_location(scope, %{
                 "slug" => "manitoba",
                 "name_en" => "Manitoba",
                 "is_private" => "false",
                 "location_type" => "subdivision1",
                 "parent_id" => country.id
               })

      assert %{location_type: ["can't be subdivision1 for a user location"]} =
               errors_on(changeset)
    end
  end

  describe "create_location/2 slug uniqueness" do
    setup do
      country = insert(:country, name_en: "Canada")
      %{country: country}
    end

    defp create_city(scope, slug, country) do
      Geo.create_location(scope, %{
        "slug" => slug,
        "name_en" => "City #{slug}",
        "is_private" => "false",
        "location_type" => "city",
        "parent_id" => country.id
      })
    end

    test "rejects a duplicate slug within one user", %{country: country} do
      %{scope: scope} = scope_fixture()

      assert {:ok, _} = create_city(scope, "shared-slug", country)
      assert {:error, changeset} = create_city(scope, "shared-slug", country)
      assert %{slug: ["has already been taken"]} = errors_on(changeset)
    end

    test "allows the same slug for two different users", %{country: country} do
      %{scope: scope_a} = scope_fixture()
      %{scope: scope_b} = scope_fixture()

      assert {:ok, _} = create_city(scope_a, "shared-slug", country)
      assert {:ok, _} = create_city(scope_b, "shared-slug", country)
    end
  end

  describe "common locations slug uniqueness" do
    test "rejects a second common location with the same slug" do
      insert(:country, slug: "canada")

      assert_raise Ecto.ConstraintError, ~r/locations_common_slug_index/, fn ->
        Repo.insert!(%Kjogvi.Geo.Location{
          slug: "canada",
          name_en: "Canada (dup)",
          location_type: :country,
          is_private: false
        })
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

      %{scope: scope, owner: owner, country: country, subdivision1: subdivision1}
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
      owner: owner,
      country: country
    } do
      # A user-assignable level (a user can't own `subdivision1`), kept at the
      # same type across the update.
      subdivision2 =
        insert(:location,
          name_en: "Some County",
          location_type: :subdivision2,
          country: country,
          user_id: owner.id,
          slug: "some-county"
        )

      city =
        insert(:location,
          name_en: "Winnipeg",
          location_type: :city,
          country: country,
          subdivision2_id: subdivision2.id
        )

      assert {:ok, _} =
               Geo.update_location(scope, subdivision2, %{
                 "name_en" => "Some County (renamed)",
                 "location_type" => "subdivision2",
                 "parent_id" => country.id
               })

      reloaded_city = Repo.get!(Kjogvi.Geo.Location, city.id)
      assert reloaded_city.subdivision2_id == subdivision2.id
      assert reloaded_city.city_id == nil
    end
  end

  defp scope_fixture do
    user = user_fixture()
    %{user: user, scope: %Kjogvi.Scope{current_user: user, area: :private}}
  end
end
