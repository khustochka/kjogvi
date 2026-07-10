defmodule Kjogvi.Search.TaxonTest do
  use Kjogvi.DataCase

  alias Kjogvi.Search.Taxon
  alias Kjogvi.AccountsFixtures
  alias Kjogvi.GeoFixtures
  alias Kjogvi.BirdingFixtures

  describe "search_taxa/2" do
    setup do
      user = AccountsFixtures.user_fixture()
      {:ok, user: user}
    end

    test "returns empty list for empty query", %{user: user} do
      assert Taxon.search_taxa("", user) == []
      assert Taxon.search_taxa(nil, user) == []
    end

    test "returns empty list when user has no default book", %{user: _user} do
      user_no_book = AccountsFixtures.user_fixture(%{default_book_signature: nil})
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

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      location = GeoFixtures.location_fixture()

      # Create observations: Great Bustard observed 5 times, Great Tit observed 1 time
      for _ <- 1..5 do
        BirdingFixtures.checklist_fixture(%{
          user: user,
          location_id: location.id,
          observations: [%{taxon_key: "/ebird/v2024/grebut1"}]
        })
      end

      BirdingFixtures.checklist_fixture(%{
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

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("yellow-rumped wa", user)
      codes = Enum.map(results, & &1.code)

      assert "yerwar1" in codes
      refute "rinbil1" in codes
    end

    test "matches a possessive name without treating the apostrophe as a boundary",
         %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "gamqua1",
        name_en: "Gambel's Quail",
        name_sci: "Callipepla gambelii"
      )

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      # "gambel" is a prefix of the word "Gambel's" — the apostrophe stays
      # inside the word rather than splitting off a "s" fragment.
      results = Taxon.search_taxa("gambel", user)
      assert "gamqua1" in Enum.map(results, & &1.code)
    end

    test "treats a slash in a group name as a word boundary", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "colpra1",
        name_en: "Collared/Oriental Pratincole",
        name_sci: "Glareola pratincola/maldivarum"
      )

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      # "oriental" follows a slash with no space; it must still match.
      results = Taxon.search_taxa("oriental", user)
      assert "colpra1" in Enum.map(results, & &1.code)
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

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
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

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("great cr", user)
      codes = Enum.map(results, & &1.code)

      assert "grcgre1" in codes
      refute "grrwar1" in codes
    end

    test "matches a taxon by its primary code prefix", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "houspa",
        name_en: "House Sparrow",
        name_sci: "Passer domesticus"
      )

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      # "hous" is a prefix of the code "houspa".
      results = Taxon.search_taxa("hous", user)
      assert "houspa" in Enum.map(results, & &1.code)
    end

    test "matches a taxon by an entry in its codes array", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "gretit1",
        codes: ["GRETI", "PARMAJ"],
        name_en: "Great Tit",
        name_sci: "Parus major"
      )

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      results = Taxon.search_taxa("parmaj", user)
      assert "gretit1" in Enum.map(results, & &1.code)
    end

    test "does not match a code as a mid-string substring", %{user: _user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "houspa",
        name_en: "House Sparrow",
        name_sci: "Passer domesticus"
      )

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      # "ouspa" is inside the code but not a prefix of it — no match.
      results = Taxon.search_taxa("ouspa", user)
      refute "houspa" in Enum.map(results, & &1.code)
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

      user = AccountsFixtures.user_fixture()

      {:ok, user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          "default_book_signature" => "ebird/v2024"
        })

      location = GeoFixtures.location_fixture()

      BirdingFixtures.checklist_fixture(%{
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
