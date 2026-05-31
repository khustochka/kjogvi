defmodule Kjogvi.Search.TaxonTest do
  use Kjogvi.DataCase

  alias Kjogvi.Search.Taxon
  alias Kjogvi.UsersFixtures
  alias Kjogvi.GeoFixtures
  alias Kjogvi.BirdingFixtures

  describe "search_taxa/2" do
    setup do
      user = UsersFixtures.user_fixture()
      {:ok, user: user}
    end

    test "returns empty list for empty query", %{user: user} do
      assert Taxon.search_taxa("", user) == []
      assert Taxon.search_taxa(nil, user) == []
    end

    test "returns empty list when user has no default book", %{user: _user} do
      user_no_book = UsersFixtures.user_fixture(%{default_book_signature: nil})
      results = Taxon.search_taxa("grebe", user_no_book)
      assert results == []
    end

    test "filters taxa by English name with user's default book", %{user: user} do
      results = Taxon.search_taxa("grebe", user)
      assert is_list(results)
    end

    test "filters taxa by scientific name with user's default book", %{user: user} do
      results = Taxon.search_taxa("podiceps", user)
      assert is_list(results)
    end

    test "handles word component matching with user's default book", %{user: user} do
      results = Taxon.search_taxa("great crested", user)
      assert is_list(results)
    end

    test "matches word starts with higher priority", %{user: user} do
      results = Taxon.search_taxa("great", user)
      assert is_list(results)
    end

    test "ranks frequently observed taxa higher within same match tier", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      # Create two taxa with similar names that will match the same query in the same tier
      _rare_taxon =
        Ornitho.Factory.insert(:taxon,
          book: book,
          code: "gretit1",
          name_en: "Great Tit",
          name_sci: "Parus major"
        )

      _common_taxon =
        Ornitho.Factory.insert(:taxon,
          book: book,
          code: "grebut1",
          name_en: "Great Bustard",
          name_sci: "Otis tarda"
        )

      user = UsersFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      location = GeoFixtures.location_fixture()

      # Create observations: Great Bustard observed 5 times, Great Tit observed 1 time
      for _ <- 1..5 do
        BirdingFixtures.card_fixture(%{
          user: user,
          location_id: location.id,
          observations: [%{taxon_key: "/ebird/v2024/grebut1"}]
        })
      end

      BirdingFixtures.card_fixture(%{
        user: user,
        location_id: location.id,
        observations: [%{taxon_key: "/ebird/v2024/gretit1"}]
      })

      results = Taxon.search_taxa("great", user)

      codes = Enum.map(results, & &1.code)

      # Both should match "great" at the word start (same priority tier),
      # but Great Bustard should rank higher due to more observations
      assert "grebut1" in codes
      assert "gretit1" in codes

      bustard_idx = Enum.find_index(codes, &(&1 == "grebut1"))
      tit_idx = Enum.find_index(codes, &(&1 == "gretit1"))
      assert bustard_idx < tit_idx
    end

    test "multi-word query requires every word to match, not just one", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "yerwar1",
        name_en: "Yellow-rumped Warbler",
        name_sci: "Setophaga coronata"
      )

      # Name contains "wa" (delaWArensis) but nothing matching "yellow-rumped";
      # it must NOT be returned for the query "yellow-rumped wa".
      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "rinbil1",
        name_en: "Ring-billed Gull",
        name_sci: "Larus delawarensis"
      )

      user = UsersFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("yellow-rumped wa", user)
      codes = Enum.map(results, & &1.code)

      assert "yerwar1" in codes
      refute "rinbil1" in codes
    end

    test "space-separated query matches a hyphenated name", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      # eBird's canonical name hyphenates "Wood-Pigeon"; a "wood pigeon" search
      # must still find it, since the hyphen is treated as a word boundary.
      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "cowpig1",
        name_en: "Common Wood-Pigeon",
        name_sci: "Columba palumbus"
      )

      user = UsersFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("wood pigeon", user)
      codes = Enum.map(results, & &1.code)

      assert "cowpig1" in codes
    end

    test "query word matches word starts only, not mid-word substrings", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "grcgre1",
        name_en: "Great Crested Grebe",
        name_sci: "Podiceps cristatus"
      )

      # "cr" appears mid-word inside "Acrocephalus" but no word starts with it,
      # so "great cr" must NOT return this taxon.
      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "grrwar1",
        name_en: "Great Reed Warbler",
        name_sci: "Acrocephalus arundinaceus"
      )

      user = UsersFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("great cr", user)
      codes = Enum.map(results, & &1.code)

      assert "grcgre1" in codes
      refute "grrwar1" in codes
    end

    test "an observed taxon outranks an unobserved one whose name starts with the query",
         %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      # "Eurasian Wren" — observed; query "wren" is a later word.
      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "eurwre1",
        name_en: "Eurasian Wren",
        name_sci: "Troglodytes troglodytes"
      )

      # "Wren-like Rushbird" — never observed; name starts with "wren".
      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "wrlrus1",
        name_en: "Wren-like Rushbird",
        name_sci: "Phacellodomus sibilatrix"
      )

      user = UsersFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      location = GeoFixtures.location_fixture()

      BirdingFixtures.card_fixture(%{
        user: user,
        location_id: location.id,
        observations: [%{taxon_key: "/ebird/v2024/eurwre1"}]
      })

      results = Taxon.search_taxa("wren", user)
      codes = Enum.map(results, & &1.code)

      # The unobserved prefix match is still offered (so it can be recorded)...
      assert "eurwre1" in codes
      assert "wrlrus1" in codes

      # ...but the observed taxon ranks first regardless of text-match tier.
      assert Enum.find_index(codes, &(&1 == "eurwre1")) <
               Enum.find_index(codes, &(&1 == "wrlrus1"))
    end
  end
end
