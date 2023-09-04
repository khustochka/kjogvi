defmodule OrnithologueTest do
  use Ornitho.RepoCase, async: true

  alias Ornitho.Schema.Taxon

  describe "get_taxa_and_species/1" do
    test "returns empty response if no codes provided" do
      # Adding a book, because there was a bug when it tried to search all books
      # if there was no restriction
      insert(:book)
      assert Ornithologue.get_taxa_and_species([]) == %{}
    end

    test "returns correct taxon" do
      taxon = insert(:taxon)
      key = Taxon.key(taxon)
      result = Ornithologue.get_taxa_and_species([key])
      assert result[key].code == taxon.code
    end

    test "returns correct taxa from multiple books" do
      taxon1 = insert(:taxon)
      taxon2 = insert(:taxon)
      assert taxon1.book != taxon2.book
      key1 = Taxon.key(taxon1)
      key2 = Taxon.key(taxon2)
      result = Ornithologue.get_taxa_and_species([key1, key2])
      assert result[key1].code == taxon1.code
      assert result[key2].code == taxon2.code
    end

    test "preloads taxon parent species" do
      species = insert(:taxon)
      taxon = insert(:taxon, book: species.book, category: "issf", parent_species: species)
      key = Taxon.key(taxon)
      result = Ornithologue.get_taxa_and_species([key])
      assert result[key].code == taxon.code
      assert result[key].parent_species.code == species.code
    end

    test "returns nil for non-existent taxon in existing book" do
      book = insert(:book)
      key = "/#{book.slug}/#{book.version}/unknown"
      result = Ornithologue.get_taxa_and_species([key])
      # assert Map.has_key?(result, key)
      assert result[key] == nil
    end

    test "returns nil for non-existent taxon in non-existent book" do
      key = "/nobook/noversion/unknown"
      result = Ornithologue.get_taxa_and_species([key])
      # assert Map.has_key?(result, key)
      assert result[key] == nil
    end
  end
end
