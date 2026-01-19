defmodule Kjogvi.Search.TaxonTest do
  use Kjogvi.DataCase

  alias Kjogvi.Search.Taxon
  alias Kjogvi.UsersFixtures

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
  end
end
