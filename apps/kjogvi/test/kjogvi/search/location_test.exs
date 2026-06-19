defmodule Kjogvi.Search.LocationTest do
  use Kjogvi.DataCase

  alias Kjogvi.Geo.Location
  alias Kjogvi.Search.Location, as: Search
  alias Kjogvi.GeoFixtures

  describe "search_locations/3 with a restricted base query" do
    test "searches only within the supplied query" do
      import Ecto.Query

      keep = GeoFixtures.location_fixture(%{slug: "keep-park", name_en: "Park Keep"})
      drop = GeoFixtures.location_fixture(%{slug: "drop-park", name_en: "Park Drop"})

      query = from(l in Location, where: l.id == ^keep.id)
      ids = Search.search_locations(query, "Park") |> Enum.map(& &1.id)

      assert keep.id in ids
      refute drop.id in ids
    end
  end

  describe "search_locations/3" do
    test "returns empty list for empty or non-string query" do
      assert Search.search_locations(Location, "") == []
      assert Search.search_locations(Location, "   ") == []
      assert Search.search_locations(Location, nil) == []
    end

    test "matches by name_en" do
      loc = GeoFixtures.location_fixture(%{slug: "central-park", name_en: "Central Park"})

      results = Search.search_locations(Location, "Central")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "matches by slug" do
      loc = GeoFixtures.location_fixture(%{slug: "assiniboine-park", name_en: "Assiniboine Park"})

      results = Search.search_locations(Location, "assiniboine-park")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "matches by iso_code" do
      loc =
        GeoFixtures.location_fixture(%{
          slug: "canada",
          name_en: "Canada",
          location_type: "country",
          iso_code: "CA"
        })

      results = Search.search_locations(Location, "CA")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "case-insensitive" do
      loc = GeoFixtures.location_fixture(%{slug: "abc-park", name_en: "Abc Park"})

      results = Search.search_locations(Location, "abc park")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "prioritizes exact iso_code match over substring matches" do
      us =
        GeoFixtures.location_fixture(%{
          slug: "united-states",
          name_en: "United States",
          location_type: "country",
          iso_code: "US"
        })

      _belarus =
        GeoFixtures.location_fixture(%{
          slug: "belarus",
          name_en: "Belarus",
          location_type: "country",
          iso_code: "BY"
        })

      _australia =
        GeoFixtures.location_fixture(%{
          slug: "australia",
          name_en: "Australia",
          location_type: "country",
          iso_code: "AU"
        })

      results = Search.search_locations(Location, "US")
      assert hd(results).id == us.id
    end

    test "prioritizes exact name match over starts-with" do
      exact = GeoFixtures.location_fixture(%{slug: "park", name_en: "Park"})
      _starts = GeoFixtures.location_fixture(%{slug: "park-street", name_en: "Park Street"})

      results = Search.search_locations(Location, "Park")
      assert hd(results).id == exact.id
    end

    test "prioritizes starts-with over word-start" do
      starts = GeoFixtures.location_fixture(%{slug: "park-street", name_en: "Park Street"})
      _word = GeoFixtures.location_fixture(%{slug: "central-park", name_en: "Central Park"})

      results = Search.search_locations(Location, "park")
      assert hd(results).id == starts.id
    end

    test "prioritizes word-start over plain contains" do
      word_start = GeoFixtures.location_fixture(%{slug: "central-park", name_en: "Central Park"})
      _contains = GeoFixtures.location_fixture(%{slug: "sparking", name_en: "Sparking"})

      results = Search.search_locations(Location, "park")
      ids = Enum.map(results, & &1.id)
      assert Enum.find_index(ids, &(&1 == word_start.id)) == 0
    end

    test "word-start matches on slug too" do
      loc = GeoFixtures.location_fixture(%{slug: "abc-park", name_en: "Foobar"})

      results = Search.search_locations(Location, "park")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "treats a slash as a word boundary even without surrounding spaces" do
      loc =
        GeoFixtures.location_fixture(%{slug: "kildonan-transcona", name_en: "Kildonan/Transcona"})

      results = Search.search_locations(Location, "transcona")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "matches a word that starts right after an opening quote" do
      loc = GeoFixtures.location_fixture(%{slug: "park-veselka", name_en: ~s(Park "Veselka")})

      results = Search.search_locations(Location, "veselka")
      assert Enum.any?(results, fn r -> r.id == loc.id end)
    end

    test "respects limit option" do
      for i <- 1..5 do
        GeoFixtures.location_fixture(%{slug: "park-#{i}", name_en: "Park #{i}"})
      end

      results = Search.search_locations(Location, "Park", limit: 3)
      assert length(results) == 3
    end

    test "returns full Location structs" do
      loc = GeoFixtures.location_fixture(%{slug: "test-loc", name_en: "Test Location"})

      [result] = Search.search_locations(Location, "Test")
      assert result.id == loc.id
      assert result.name_en == "Test Location"
      assert result.slug == "test-loc"
      assert Ecto.assoc_loaded?(result.cached_country)
    end

    test "includes private locations" do
      private =
        GeoFixtures.location_fixture(%{
          slug: "private-park",
          name_en: "Private Park",
          is_private: true
        })

      results = Search.search_locations(Location, "Private")
      assert Enum.any?(results, fn r -> r.id == private.id end)
    end
  end
end
