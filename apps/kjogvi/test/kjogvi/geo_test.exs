defmodule Kjogvi.GeoTest do
  use Kjogvi.DataCase, async: true

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
      parent = insert(:location)
      insert(:location, ancestry: [parent.id])
      insert(:location, ancestry: [parent.id])

      assert Geo.children_count(parent.id) == 2
    end

    test "counts nested descendants" do
      grandparent = insert(:location)
      parent = insert(:location, ancestry: [grandparent.id])
      insert(:location, ancestry: [grandparent.id, parent.id])

      assert Geo.children_count(grandparent.id) == 2
    end

    test "does not count unrelated locations" do
      location = insert(:location)
      insert(:location)

      assert Geo.children_count(location.id) == 0
    end
  end

  describe "get_lifelist_location_context/1" do
    test "World (nil) returns continents as siblings and countries as children" do
      europe = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)

      germany =
        insert(:location, name_en: "Germany", ancestry: [europe.id], public_index: 2)

      # Location without public_index should not appear
      insert(:location, name_en: "Hidden", ancestry: [], public_index: nil)

      result = Geo.get_lifelist_location_context(nil)

      assert result.ancestors == []
      assert Enum.map(result.siblings, & &1.id) == [europe.id]
      assert Enum.map(result.children, & &1.id) == [germany.id]
    end

    test "specific location returns ancestors, siblings, and children" do
      europe = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)

      germany =
        insert(:location, name_en: "Germany", ancestry: [europe.id], public_index: 2)

      france =
        insert(:location, name_en: "France", ancestry: [europe.id], public_index: 3)

      berlin =
        insert(:location,
          name_en: "Berlin",
          ancestry: [europe.id, germany.id],
          public_index: 4
        )

      result = Geo.get_lifelist_location_context(germany)

      assert Enum.map(result.ancestors, & &1.id) == [europe.id]
      assert Enum.map(result.siblings, & &1.id) == [france.id]
      assert Enum.map(result.children, & &1.id) == [berlin.id]
    end

    test "deep location preserves ancestor order from ancestry" do
      continent = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)
      country = insert(:location, name_en: "Germany", ancestry: [continent.id], public_index: 2)

      city =
        insert(:location,
          name_en: "Berlin",
          ancestry: [continent.id, country.id],
          public_index: 3
        )

      result = Geo.get_lifelist_location_context(city)

      assert Enum.map(result.ancestors, & &1.id) == [continent.id, country.id]
      assert result.siblings == []
      assert result.children == []
    end

    test "excludes locations without public_index" do
      europe = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)

      insert(:location, name_en: "Private Country", ancestry: [europe.id], public_index: nil)

      result = Geo.get_lifelist_location_context(europe)

      assert result.children == []
    end

    test "siblings are determined by effective lifelist parent, not exact ancestry" do
      europe = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)
      ukraine = insert(:location, name_en: "Ukraine", ancestry: [europe.id], public_index: 2)

      oblast =
        insert(:location,
          name_en: "Kyiv Oblast",
          ancestry: [europe.id, ukraine.id],
          public_index: 3
        )

      # district has no public_index — it's an intermediary
      district =
        insert(:location,
          name_en: "Brovary district",
          ancestry: [europe.id, ukraine.id, oblast.id],
          public_index: nil
        )

      kyiv =
        insert(:location,
          name_en: "Kyiv",
          ancestry: [europe.id, ukraine.id, oblast.id],
          public_index: 4
        )

      brovary =
        insert(:location,
          name_en: "Brovary",
          ancestry: [europe.id, ukraine.id, oblast.id, district.id],
          public_index: 5
        )

      # Both have effective lifelist parent = oblast, so they are siblings
      result = Geo.get_lifelist_location_context(kyiv)
      assert brovary.id in Enum.map(result.siblings, & &1.id)

      result2 = Geo.get_lifelist_location_context(brovary)
      assert kyiv.id in Enum.map(result2.siblings, & &1.id)
    end

    test "children are determined by nearest lifelist ancestor, skipping intermediaries" do
      continent = insert(:location, name_en: "Europe", ancestry: [], public_index: 1)
      country = insert(:location, name_en: "Germany", ancestry: [continent.id], public_index: nil)

      city =
        insert(:location,
          name_en: "Berlin",
          ancestry: [continent.id, country.id],
          public_index: 2
        )

      # Berlin's nearest lifelist ancestor is Europe (Germany has no public_index)
      result = Geo.get_lifelist_location_context(continent)

      assert Enum.map(result.children, & &1.id) == [city.id]

      # And from World view, Berlin should NOT be a child (its effective parent is Europe, a sibling)
      world_result = Geo.get_lifelist_location_context(nil)
      assert Enum.map(world_result.children, & &1.id) == [city.id]
    end
  end

  describe "get_countries/0" do
    test "returns only locations with country type" do
      insert(:location, location_type: "country", name_en: "Canada")
      insert(:location, location_type: "region", name_en: "Manitoba")
      insert(:location, name_en: "Winnipeg")

      countries = Geo.get_countries()
      assert length(countries) == 1
      assert hd(countries).name_en == "Canada"
    end

    test "returns empty list when no countries exist" do
      insert(:location, location_type: "region")

      assert Geo.get_countries() == []
    end
  end

  describe "get_specials/0" do
    test "returns only special locations" do
      insert(:location, location_type: "special", name_en: "5MR")
      insert(:location, location_type: "country", name_en: "Canada")

      specials = Geo.get_specials()
      assert length(specials) == 1
      assert hd(specials).name_en == "5MR"
    end

    test "returns empty list when no specials exist" do
      insert(:location, location_type: "country")

      assert Geo.get_specials() == []
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
      scope = %Kjogvi.Scope{user: nil, private_view: false}

      result = Geo.location_by_slug_scope(scope, "public-loc")
      assert result.id == location.id
    end

    test "does not return private location for anonymous scope" do
      insert(:location, slug: "private-loc", is_private: true)
      scope = %Kjogvi.Scope{user: nil, private_view: false}

      assert Geo.location_by_slug_scope(scope, "private-loc") == nil
    end

    test "returns private location for authenticated scope with private_view" do
      location = insert(:location, slug: "private-loc", is_private: true)

      import Kjogvi.UsersFixtures
      user = user_fixture()
      scope = %Kjogvi.Scope{user: user, private_view: true}

      result = Geo.location_by_slug_scope(scope, "private-loc")
      assert result.id == location.id
    end

    test "does not return private location for authenticated scope without private_view" do
      insert(:location, slug: "private-loc", is_private: true)

      import Kjogvi.UsersFixtures
      user = user_fixture()
      scope = %Kjogvi.Scope{user: user, private_view: false}

      assert Geo.location_by_slug_scope(scope, "private-loc") == nil
    end
  end

  describe "search_locations/2" do
    test "finds locations by name" do
      insert(:location, name_en: "Assiniboine Park")
      insert(:location, name_en: "Fort Whyte")

      results = Geo.search_locations("Assiniboine")
      assert length(results) == 1
      assert hd(results).name_en == "Assiniboine Park"
    end

    test "finds locations by slug" do
      insert(:location, slug: "assiniboine-park", name_en: "Assiniboine Park")

      results = Geo.search_locations("assiniboine-park")
      assert length(results) == 1
    end

    test "finds locations by iso_code" do
      insert(:location, iso_code: "CA", name_en: "Canada", location_type: "country")

      results = Geo.search_locations("CA")
      assert length(results) == 1
    end

    test "search is case-insensitive" do
      insert(:location, name_en: "Assiniboine Park")

      results = Geo.search_locations("assiniboine")
      assert length(results) == 1
    end

    test "respects limit option" do
      for i <- 1..5 do
        insert(:location, name_en: "Park #{i}")
      end

      results = Geo.search_locations("Park", limit: 3)
      assert length(results) == 3
    end

    test "returns empty list for no matches" do
      insert(:location, name_en: "Assiniboine Park")

      assert Geo.search_locations("Nonexistent") == []
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

  describe "all_locations_by_parent/0" do
    test "returns locations grouped by parent id" do
      parent = insert(:location)
      insert(:location, ancestry: [parent.id])
      insert(:location, ancestry: [parent.id])

      grouped = Geo.all_locations_by_parent()

      assert length(grouped[parent.id]) == 2
      assert grouped[nil] != []
    end

    test "excludes special locations" do
      insert(:location, location_type: "special")
      insert(:location, location_type: "country")

      grouped = Geo.all_locations_by_parent()
      all = Enum.flat_map(grouped, fn {_k, v} -> v end)
      refute Enum.any?(all, &(&1.location_type == "special"))
    end
  end

  describe "get_child_locations/1" do
    test "returns child locations with card counts" do
      parent = insert(:location)
      child = insert(:location, ancestry: [parent.id])
      insert(:card, location: child)

      results = Geo.get_child_locations(parent.id)
      assert length(results) == 1
      assert hd(results).cards_count == 1
    end

    test "excludes special locations" do
      parent = insert(:location)
      insert(:location, ancestry: [parent.id], location_type: "special")
      insert(:location, ancestry: [parent.id], location_type: nil)

      results = Geo.get_child_locations(parent.id)
      assert length(results) == 1
    end

    test "returns nested descendants" do
      grandparent = insert(:location)
      parent = insert(:location, ancestry: [grandparent.id])
      insert(:location, ancestry: [grandparent.id, parent.id])

      results = Geo.get_child_locations(grandparent.id)
      assert length(results) == 2
    end
  end

  describe "get_upper_level_locations/0" do
    test "includes countries" do
      country = insert(:location, location_type: "country")

      results = Geo.get_upper_level_locations()
      assert Enum.any?(results, &(&1.id == country.id))
    end

    test "includes regions" do
      country = insert(:location, location_type: "country")
      region = insert(:location, location_type: "region", ancestry: [country.id])

      results = Geo.get_upper_level_locations()
      assert Enum.any?(results, &(&1.id == region.id))
    end

    test "excludes special locations" do
      insert(:location, location_type: "special")

      results = Geo.get_upper_level_locations()
      refute Enum.any?(results, &(&1.location_type == "special"))
    end
  end
end
