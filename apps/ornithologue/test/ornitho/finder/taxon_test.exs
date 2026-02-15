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

    test "respects the limit option" do
      book = insert(:book)
      insert(:taxon, book: book, name_en: "House Sparrow")
      insert(:taxon, book: book, name_en: "House Finch")
      insert(:taxon, book: book, name_en: "House Wren")

      result = Ornitho.Finder.Taxon.search(book, "house", limit: 2)
      assert length(result) == 2
    end

    test "does not search in the wrong book" do
      book1 = insert(:book)
      book2 = insert(:book)

      taxon1 =
        insert(:taxon,
          book: book1,
          name_sci: "Nucifraga caryocatactes",
          name_en: "Eurasian Nutcracker"
        )

      taxon2 =
        insert(:taxon,
          book: book2,
          name_sci: "Nucifraga caryocatactes",
          name_en: "Northern Nutcracker"
        )

      result = Ornitho.Finder.Taxon.search(book1, "nutcracker")
      ids = Enum.map(result, & &1.id)
      assert taxon1.id in ids
      assert taxon2.id not in ids
    end
  end

  describe "by_name_sci/2" do
    test "finds a taxon by scientific name" do
      book = insert(:book)
      taxon = insert(:taxon, book: book, name_sci: "Parus major")

      result = Ornitho.Finder.Taxon.by_name_sci(book, "Parus major")
      assert result.id == taxon.id
    end

    test "returns nil when not found" do
      book = insert(:book)
      assert Ornitho.Finder.Taxon.by_name_sci(book, "Nonexistent") == nil
    end
  end

  describe "by_code/2" do
    test "finds a taxon by code" do
      book = insert(:book)
      taxon = insert(:taxon, book: book, code: "parmaj")

      result = Ornitho.Finder.Taxon.by_code(book, "parmaj")
      assert result.id == taxon.id
    end

    test "returns nil when not found" do
      book = insert(:book)
      assert Ornitho.Finder.Taxon.by_code(book, "nonexistent") == nil
    end
  end

  describe "by_code!/2" do
    test "finds a taxon by code" do
      book = insert(:book)
      taxon = insert(:taxon, book: book, code: "parmaj")

      result = Ornitho.Finder.Taxon.by_code!(book, "parmaj")
      assert result.id == taxon.id
    end

    test "raises when not found" do
      book = insert(:book)

      assert_raise Ecto.NoResultsError, fn ->
        Ornitho.Finder.Taxon.by_code!(book, "nonexistent")
      end
    end
  end

  describe "by_concept_id/1" do
    test "finds taxa by concept id across books" do
      book1 = insert(:book)
      book2 = insert(:book)
      t1 = insert(:taxon, book: book1, taxon_concept_id: "TC001")
      t2 = insert(:taxon, book: book2, taxon_concept_id: "TC001")
      _t3 = insert(:taxon, book: book1, taxon_concept_id: "TC002")

      result = Ornitho.Finder.Taxon.by_concept_id("TC001")
      ids = Enum.map(result, & &1.id)
      assert t1.id in ids
      assert t2.id in ids
      assert length(ids) == 2
    end
  end

  describe "by_codes/2" do
    test "finds multiple taxa by codes" do
      book = insert(:book)
      t1 = insert(:taxon, book: book, code: "yelwar")
      t2 = insert(:taxon, book: book, code: "comcuc")
      _t3 = insert(:taxon, book: book, code: "grewag")

      result = Ornitho.Finder.Taxon.by_codes(book, ["yelwar", "comcuc"])
      ids = Enum.map(result, & &1.id)
      assert t1.id in ids
      assert t2.id in ids
      assert length(ids) == 2
    end
  end

  describe "paginate/2" do
    test "returns a paginated result" do
      book = insert(:book)

      for i <- 1..30 do
        insert(:taxon, book: book, sort_order: i)
      end

      result = Ornitho.Finder.Taxon.paginate(book)
      assert result.page_number == 1
      assert result.page_size == 25
      assert result.total_entries == 30
      assert length(result.entries) == 25
    end

    test "respects page and page_size options" do
      book = insert(:book)

      for i <- 1..15 do
        insert(:taxon, book: book, sort_order: i)
      end

      result = Ornitho.Finder.Taxon.paginate(book, page: 2, page_size: 10)
      assert result.page_number == 2
      assert length(result.entries) == 5
    end
  end

  describe "with_parent_species/1" do
    test "preloads parent_species on a taxon" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species")
      subspecies = insert(:taxon, book: book, category: "subspecies", parent_species: parent)

      loaded = Ornitho.Finder.Taxon.with_parent_species(subspecies)
      assert loaded.parent_species.id == parent.id
    end

    test "preloads parent_species on a Scrivener.Page" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species", sort_order: 1)

      insert(:taxon,
        book: book,
        category: "subspecies",
        parent_species: parent,
        sort_order: 2
      )

      page = Ornitho.Finder.Taxon.paginate(book)
      result = Ornitho.Finder.Taxon.with_parent_species(page)
      assert %Scrivener.Page{} = result

      subspecies_entry = Enum.find(result.entries, &(&1.category == "subspecies"))
      assert subspecies_entry.parent_species.id == parent.id
    end
  end

  describe "with_book/1" do
    test "preloads book on a taxon" do
      taxon = insert(:taxon)
      loaded = Ornitho.Finder.Taxon.with_book(taxon)
      assert loaded.book.id == taxon.book_id
    end
  end

  describe "with_child_taxa/1" do
    test "preloads child_taxa on a species" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species")
      child = insert(:taxon, book: book, category: "subspecies", parent_species: parent)

      loaded = Ornitho.Finder.Taxon.with_child_taxa(parent)
      child_ids = Enum.map(loaded.child_taxa, & &1.id)
      assert child.id in child_ids
    end
  end
end
