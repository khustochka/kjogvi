defmodule Ornitho.Find.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  describe "page/1" do
    test "returns the value if per_page is empty" do
      book = insert(:book)

      taxa =
        1..26
        |> Enum.to_list()
        |> Enum.map(fn _ -> insert(:taxon, book: book) end)

      result = Ornitho.Find.Taxon.page(book, 1)
      assert Enum.map(result, & &1.id) == Enum.map(Enum.take(taxa, 25), & &1.id)
    end
  end

  describe "page/2" do
    test "returns the correct amount of taxa on the first page" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book)
      taxon2 = insert(:taxon, book: book)
      taxon3 = insert(:taxon, book: book)
      _taxon4 = insert(:taxon, book: book)
      _taxon5 = insert(:taxon, book: book)

      result = Ornitho.Find.Taxon.page(book, 1, per_page: 3)
      assert Enum.map(result, & &1.id) == Enum.map([taxon1, taxon2, taxon3], & &1.id)
    end

    test "returns the correct amount of taxa on the second page" do
      book = insert(:book)
      _taxon1 = insert(:taxon, book: book)
      _taxon2 = insert(:taxon, book: book)
      _taxon3 = insert(:taxon, book: book)
      taxon4 = insert(:taxon, book: book)
      taxon5 = insert(:taxon, book: book)

      result = Ornitho.Find.Taxon.page(book, 2, per_page: 3)
      assert Enum.map(result, & &1.id) == Enum.map([taxon4, taxon5], & &1.id)
    end
  end
end
