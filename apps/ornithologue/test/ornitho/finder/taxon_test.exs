defmodule Ornitho.Finder.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  describe "search" do
    test "searches for the start of the scientific name" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      taxon2 = insert(:taxon, book: book, name_sci: "Acrocephalus scirpaceus")
      taxon3 = insert(:taxon, book: book, name_sci: "Certhia familiaris")
      result = Ornitho.Finder.Taxon.search(book, "acro")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id in ids
      assert taxon3.id not in ids
    end

    test "searches for the part of the scientific name" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, name_sci: "Acrocephalus palustris")
      taxon2 = insert(:taxon, book: book, name_sci: "Acrocephalus scirpaceus")
      taxon3 = insert(:taxon, book: book, name_sci: "Certhia familiaris")
      result = Ornitho.Finder.Taxon.search(book, "fam")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id not in ids
      assert taxon2.id not in ids
      assert taxon3.id in ids
    end

    test "searches for the start of the common name" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, name_en: "House Sparrow")
      taxon2 = insert(:taxon, book: book, name_en: "House Finch")
      taxon3 = insert(:taxon, book: book, name_en: "Northern Wheatear")
      result = Ornitho.Finder.Taxon.search(book, "hous")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id in ids
      assert taxon3.id not in ids
    end

    test "searches for the part of the common name" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, name_en: "House Sparrow")
      taxon2 = insert(:taxon, book: book, name_en: "House Finch")
      taxon3 = insert(:taxon, book: book, name_en: "Northern Wheatear")
      result = Ornitho.Finder.Taxon.search(book, "SE")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id in ids
      assert taxon3.id not in ids
    end

    test "searches for the start of the taxon code" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, code: "yelwar")
      taxon2 = insert(:taxon, book: book, code: "yellow")
      taxon3 = insert(:taxon, book: book, code: "midmer")
      result = Ornitho.Finder.Taxon.search(book, "yel")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id in ids
      assert taxon3.id not in ids
    end

    test "does not search for the middle of the taxon code" do
      book = insert(:book)
      taxon1 = insert(:taxon, book: book, code: "yelwar")
      taxon2 = insert(:taxon, book: book, code: "yellow")
      taxon3 = insert(:taxon, book: book, code: "greyel")
      result = Ornitho.Finder.Taxon.search(book, "yel")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id in ids
      assert taxon3.id not in ids
    end

    test "using % does not allow searching for the middle of the taxon code" do
      book = insert(:book)
      insert(:taxon, book: book, code: "yelwar")
      insert(:taxon, book: book, code: "yellow")
      insert(:taxon, book: book, code: "greyel")
      result = Ornitho.Finder.Taxon.search(book, "%yel")
      assert result == []
    end
  end
end
