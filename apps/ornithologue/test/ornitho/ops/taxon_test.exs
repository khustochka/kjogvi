defmodule Ornitho.Ops.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Ops

  describe "creating one taxon" do
    test "success" do
      book = insert(:book)
      attrs = params_for(:taxon)

      assert {:ok, _} = Ops.Taxon.create(book, attrs)
    end

    test "create/2 will return error if taxon is not valid" do
      book = insert(:book)
      attrs = params_for(:taxon, name_sci: "")

      assert {:error, _} = Ops.Taxon.create(book, attrs)
    end

    test "create!/2 will raise if taxon is not valid" do
      book = insert(:book)
      attrs = params_for(:taxon, name_sci: "")

      assert_raise Ecto.InvalidChangesetError, fn ->
        Ops.Taxon.create!(book, attrs)
      end
    end
  end

  describe "set_parent_species/3" do
    test "links children to the parent species and returns the count" do
      book = insert(:book)
      parent = insert(:taxon, book: book, code: "comcuc", category: "species")
      child1 = insert(:taxon, book: book, code: "comcuc1", category: "issf")
      child2 = insert(:taxon, book: book, code: "comcuc2", category: "issf")

      assert Ops.Taxon.set_parent_species(book.id, "comcuc", ["comcuc1", "comcuc2"]) == 2

      assert OrnithoRepo.reload(child1).parent_species_id == parent.id
      assert OrnithoRepo.reload(child2).parent_species_id == parent.id
    end

    test "only updates taxa whose code is in the list" do
      book = insert(:book)
      parent = insert(:taxon, book: book, code: "comcuc", category: "species")
      child = insert(:taxon, book: book, code: "comcuc1", category: "issf")
      other = insert(:taxon, book: book, code: "comcuc2", category: "issf")

      assert Ops.Taxon.set_parent_species(book.id, "comcuc", ["comcuc1"]) == 1

      assert OrnithoRepo.reload(child).parent_species_id == parent.id
      assert OrnithoRepo.reload(other).parent_species_id == nil
    end

    test "is scoped to the given book" do
      book = insert(:book)
      other_book = insert(:book)
      insert(:taxon, book: book, code: "comcuc", category: "species")
      child_in_other = insert(:taxon, book: other_book, code: "comcuc1", category: "issf")

      assert Ops.Taxon.set_parent_species(book.id, "comcuc", ["comcuc1"]) == 0

      assert OrnithoRepo.reload(child_in_other).parent_species_id == nil
    end

    test "resolves the parent within the same book" do
      book = insert(:book)
      other_book = insert(:book)
      insert(:taxon, book: other_book, code: "comcuc", category: "species")
      child = insert(:taxon, book: book, code: "comcuc1", category: "issf")

      assert Ops.Taxon.set_parent_species(book.id, "comcuc", ["comcuc1"]) == 1

      # No parent with that code exists in `book`, so the subquery yields NULL.
      assert OrnithoRepo.reload(child).parent_species_id == nil
    end

    test "returns zero when no child codes match" do
      book = insert(:book)
      insert(:taxon, book: book, code: "comcuc", category: "species")

      assert Ops.Taxon.set_parent_species(book.id, "comcuc", ["nope"]) == 0
    end
  end
end
