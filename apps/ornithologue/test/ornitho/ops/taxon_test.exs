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

  describe "link_parent_species/1" do
    test "links children to the parent named in their extras and returns the count" do
      book = insert(:book)
      parent = insert(:taxon, book: book, code: "comcuc", category: "species")

      child1 =
        insert(:taxon,
          book: book,
          code: "comcuc1",
          category: "issf",
          extras: parent_ref("comcuc")
        )

      child2 =
        insert(:taxon,
          book: book,
          code: "comcuc2",
          category: "issf",
          extras: parent_ref("comcuc")
        )

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 2}

      assert OrnithoRepo.reload(child1).parent_species_id == parent.id
      assert OrnithoRepo.reload(child2).parent_species_id == parent.id
    end

    test "leaves taxa without a parent_species_code unlinked" do
      book = insert(:book)
      parent = insert(:taxon, book: book, code: "comcuc", category: "species")

      child =
        insert(:taxon,
          book: book,
          code: "comcuc1",
          category: "issf",
          extras: parent_ref("comcuc")
        )

      plain = insert(:taxon, book: book, code: "comcuc2", category: "species")

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 1}

      assert OrnithoRepo.reload(child).parent_species_id == parent.id
      assert OrnithoRepo.reload(plain).parent_species_id == nil
    end

    test "is scoped to the given book" do
      book = insert(:book)
      other_book = insert(:book)
      insert(:taxon, book: book, code: "comcuc", category: "species")

      child_in_other =
        insert(:taxon,
          book: other_book,
          code: "comcuc1",
          category: "issf",
          extras: parent_ref("comcuc")
        )

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 0}

      assert OrnithoRepo.reload(child_in_other).parent_species_id == nil
    end

    test "resolves the parent within the same book" do
      book = insert(:book)
      other_book = insert(:book)
      insert(:taxon, book: other_book, code: "comcuc", category: "species")

      child =
        insert(:taxon,
          book: book,
          code: "comcuc1",
          category: "issf",
          extras: parent_ref("comcuc")
        )

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 0}

      # No parent with that code exists in `book`, so the child stays unlinked.
      assert OrnithoRepo.reload(child).parent_species_id == nil
    end

    test "leaves the child unlinked when its parent_species_code matches nothing" do
      book = insert(:book)
      insert(:taxon, book: book, code: "comcuc", category: "species")

      child =
        insert(:taxon, book: book, code: "comcuc1", category: "issf", extras: parent_ref("nope"))

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 0}

      assert OrnithoRepo.reload(child).parent_species_id == nil
    end
  end

  defp parent_ref(code), do: %{"parent_species_code" => code}
end
