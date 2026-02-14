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

  describe "get_all_locations_grouped/0" do
    test "returns locations grouped by parent" do
      parent = insert(:location)
      insert(:location, ancestry: [parent.id])
      insert(:location, ancestry: [parent.id])

      {locations, grouped} = Geo.get_all_locations_grouped()
      assert length(locations) >= 3
      assert length(grouped[parent.id]) == 2
    end

    test "excludes special locations" do
      insert(:location, location_type: "special")
      insert(:location, location_type: "country")

      {locations, _grouped} = Geo.get_all_locations_grouped()
      refute Enum.any?(locations, &(&1.location_type == "special"))
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
