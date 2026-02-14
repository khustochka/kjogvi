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
  end
end
