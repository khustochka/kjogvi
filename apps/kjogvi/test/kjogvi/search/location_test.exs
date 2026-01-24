defmodule Kjogvi.Search.LocationTest do
  use Kjogvi.DataCase

  alias Kjogvi.Search.Location
  alias Kjogvi.GeoFixtures

  describe "search_locations/1" do
    test "returns empty list for empty query" do
      assert Location.search_locations("") == []
      assert Location.search_locations(nil) == []
    end

    test "filters locations by name" do
      loc =
        GeoFixtures.location_fixture(%{
          slug: "central-park",
          name_en: "Central Park",
          location_type: "park",
          is_private: false
        })

      results = Location.search_locations("Central")
      assert length(results) > 0
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "finds locations by partial name match" do
      loc =
        GeoFixtures.location_fixture(%{
          slug: "abc-park",
          name_en: "Abc Park",
          location_type: "park",
          is_private: false
        })

      results = Location.search_locations("park")
      assert length(results) > 0
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "prioritizes exact matches" do
      loc1 =
        GeoFixtures.location_fixture(%{
          slug: "park",
          name_en: "Park",
          location_type: "park",
          is_private: false
        })

      _loc2 =
        GeoFixtures.location_fixture(%{
          slug: "central-park",
          name_en: "Central Park",
          location_type: "park",
          is_private: false
        })

      results = Location.search_locations("Park")
      assert List.first(results).id == loc1.id
    end

    test "prioritizes word-start matches over contains matches" do
      start_match =
        GeoFixtures.location_fixture(%{
          slug: "park-street",
          name_en: "Park Street",
          location_type: "park",
          is_private: false
        })

      _contains_match =
        GeoFixtures.location_fixture(%{
          slug: "abc-park",
          name_en: "Abc Park",
          location_type: "park",
          is_private: false
        })

      results = Location.search_locations("Park")
      assert List.first(results).id == start_match.id
    end

    test "includes private locations" do
      _public =
        GeoFixtures.location_fixture(%{
          slug: "public-park",
          name_en: "Public Park",
          location_type: "park",
          is_private: false
        })

      _private =
        GeoFixtures.location_fixture(%{
          slug: "private-park",
          name_en: "Private Park",
          location_type: "park",
          is_private: true
        })

      results = Location.search_locations("Park")
      assert Enum.any?(results, fn r -> r.name == "Private Park" end)
    end

    test "returns long_name in results" do
      location =
        GeoFixtures.location_fixture(%{
          slug: "test-loc",
          name_en: "Test Location",
          location_type: "park",
          is_private: false
        })

      results = Location.search_locations("Test")
      assert length(results) > 0
      result = List.first(results)
      assert result.id == location.id
      assert result.name != nil
    end
  end
end
