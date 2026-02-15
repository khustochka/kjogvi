defmodule Ornitho.Schema.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Schema.Taxon

  describe "Taxon factory" do
    test "is valid" do
      taxon = insert(:taxon)
      repo_tx = OrnithoRepo.all(Taxon)

      assert length(repo_tx) == 1
      assert hd(repo_tx).code == taxon.code
    end
  end

  describe "Taxon" do
    test "same scientific names in the same book" do
      book = insert(:book)

      assert_raise(Ecto.ConstraintError, fn ->
        _tx1 = insert(:taxon, book: book, name_sci: "Cuculus canorus")
        _tx2 = insert(:taxon, book: book, name_sci: "Cuculus canorus")
      end)
    end

    test "same scientific names in different books" do
      error =
        try do
          _tx1 = insert(:taxon, name_sci: "Cuculus canorus")
          _tx2 = insert(:taxon, name_sci: "Cuculus canorus")
          nil
        rescue
          e -> e
        end

      assert error == nil
    end
  end

  describe "changeset" do
    test "cannot be saved wihout book" do
      taxon_attrs = params_for(:taxon, book_id: nil)
      assert {:error, _} = Taxon.creation_changeset(%Taxon{}, taxon_attrs) |> OrnithoRepo.insert()
    end
  end

  describe "key/1" do
    test "formats a taxon key from book slug, version, and code" do
      taxon = insert(:taxon) |> OrnithoRepo.preload(:book)
      key = Taxon.key(taxon)
      assert key == "/#{taxon.book.slug}/#{taxon.book.version}/#{taxon.code}"
    end
  end

  describe "dismantle_key/1" do
    test "parses a key string back to a tuple" do
      assert Taxon.dismantle_key("/ebird/v2024/comcuc") == {"ebird", "v2024", "comcuc"}
    end
  end

  describe "species/1" do
    test "returns nil when taxon is nil" do
      assert Taxon.species(nil) == nil
    end

    test "returns the taxon itself when category is species" do
      taxon = insert(:taxon, category: "species")
      assert Taxon.species(taxon) == taxon
    end

    test "returns the parent_species when present" do
      book = insert(:book)
      parent = insert(:taxon, book: book, category: "species")

      subspecies =
        insert(:taxon, book: book, category: "subspecies", parent_species: parent)
        |> OrnithoRepo.preload(:parent_species)

      assert Taxon.species(subspecies).id == parent.id
    end

    test "returns nil for non-species without parent" do
      taxon = insert(:taxon, category: "slash", parent_species: nil)
      assert Taxon.species(taxon) == nil
    end
  end

  describe "formatted_authority/1" do
    test "returns nil when authority is nil" do
      taxon = %Taxon{authority: nil}
      assert Taxon.formatted_authority(taxon) == nil
    end

    test "wraps authority in brackets when authority_brackets is true" do
      taxon = %Taxon{authority: "Linnaeus, 1758", authority_brackets: true}
      assert Taxon.formatted_authority(taxon) == "(Linnaeus, 1758)"
    end

    test "returns authority without brackets when authority_brackets is false" do
      taxon = %Taxon{authority: "Linnaeus, 1758", authority_brackets: false}
      assert Taxon.formatted_authority(taxon) == "Linnaeus, 1758"
    end
  end

  describe "extinct?/1" do
    test "returns true when extras has extinct flag" do
      taxon = %Taxon{extras: %{"extinct" => true}}
      assert Taxon.extinct?(taxon)
    end

    test "returns nil when extras has no extinct flag" do
      taxon = %Taxon{extras: %{}}
      refute Taxon.extinct?(taxon)
    end

    test "returns nil when extras is nil" do
      taxon = %Taxon{extras: nil}
      refute Taxon.extinct?(taxon)
    end
  end

  describe "updating_changeset/2" do
    test "returns a valid changeset for updates" do
      taxon = insert(:taxon)
      changeset = Taxon.updating_changeset(taxon, %{name_en: "Updated Name"})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name_en) == "Updated Name"
    end

    test "does not allow changing book_id" do
      taxon = insert(:taxon)
      changeset = Taxon.updating_changeset(taxon, %{book_id: 999})
      refute Ecto.Changeset.get_change(changeset, :book_id)
    end
  end
end
