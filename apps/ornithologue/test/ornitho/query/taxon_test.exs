defmodule Ornitho.Query.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  alias Ornitho.Query

  describe "by_codes/2" do
    test "filters taxa by a list of codes" do
      book = insert(:book)
      t1 = insert(:taxon, book: book, code: "parmaj")
      t2 = insert(:taxon, book: book, code: "motfla")
      _t3 = insert(:taxon, book: book, code: "sylatr")

      result =
        Query.Taxon.by_book(book)
        |> Query.Taxon.by_codes(["parmaj", "motfla"])
        |> OrnithoRepo.all()

      ids = Enum.map(result, & &1.id)
      assert t1.id in ids
      assert t2.id in ids
      assert length(ids) == 2
    end
  end

  describe "by_being_countable/1" do
    test "includes species" do
      book = insert(:book)
      species = insert(:taxon, book: book, category: "species")

      result =
        Query.Taxon.by_book(book)
        |> Query.Taxon.by_being_countable()
        |> OrnithoRepo.all()

      ids = Enum.map(result, & &1.id)
      assert species.id in ids
    end

    test "includes subspecies with parent" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species")
      subspecies = insert(:taxon, book: book, category: "subspecies", parent_species: parent)

      result =
        Query.Taxon.by_book(book)
        |> Query.Taxon.by_being_countable()
        |> OrnithoRepo.all()

      ids = Enum.map(result, & &1.id)
      assert subspecies.id in ids
    end

    test "excludes uncountable taxa without parent" do
      book = insert(:book)
      _slash = insert(:taxon, book: book, category: "slash", parent_species: nil)

      result =
        Query.Taxon.by_book(book)
        |> Query.Taxon.by_being_countable()
        |> OrnithoRepo.all()

      assert result == []
    end
  end

  describe "select_by_format/2" do
    test "with :full format returns all fields" do
      book = insert(:book)
      insert(:taxon, book: book, authority: "Linnaeus, 1758")

      [taxon] =
        Query.Taxon.by_book(book)
        |> Query.Taxon.select_by_format(:full)
        |> OrnithoRepo.all()

      assert taxon.authority == "Linnaeus, 1758"
    end

    test "with minimal format selects only key fields" do
      book = insert(:book)
      insert(:taxon, book: book, authority: "Linnaeus, 1758")

      [taxon] =
        Query.Taxon.by_book(book)
        |> Query.Taxon.select_by_format(:minimal)
        |> OrnithoRepo.all()

      assert taxon.code
      assert taxon.name_sci
      # authority is not in the minimal select
      refute taxon.authority
    end
  end

  describe "base_ordered/1" do
    test "returns taxa for a book ordered by sort_order" do
      book = insert(:book)
      t3 = insert(:taxon, book: book, sort_order: 3)
      t1 = insert(:taxon, book: book, sort_order: 1)
      t2 = insert(:taxon, book: book, sort_order: 2)

      result =
        Query.Taxon.base_ordered(book)
        |> OrnithoRepo.all()

      assert Enum.map(result, & &1.id) == [t1.id, t2.id, t3.id]
    end
  end

  describe "with_parent_species/1" do
    test "preloads parent_species association" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species")
      _child = insert(:taxon, book: book, category: "subspecies", parent_species: parent)

      [species, subspecies] =
        Query.Taxon.by_book(book)
        |> Query.Taxon.ordered()
        |> Query.Taxon.with_parent_species()
        |> OrnithoRepo.all()

      assert is_nil(species.parent_species)
      assert subspecies.parent_species.id == parent.id
    end
  end

  describe "search/2" do
    test "matches by taxon_concept_id" do
      book = insert(:book)
      taxon = insert(:taxon, book: book, taxon_concept_id: "avibase-ABC123")
      _other = insert(:taxon, book: book, taxon_concept_id: "avibase-XYZ789")

      result =
        Query.Taxon.by_book(book)
        |> Query.Taxon.search("avibase-ABC123")
        |> OrnithoRepo.all()

      assert length(result) == 1
      assert hd(result).id == taxon.id
    end
  end
end
