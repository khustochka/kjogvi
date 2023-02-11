defmodule Ornitho.Schema.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Schema.Taxon

  describe "Taxon" do
    test "is saved" do
      tx = insert(:taxon)

      assert [taxon] = Repo.all(Taxon)

      assert taxon.name_sci == tx.name_sci
    end

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
      assert {:error, _} = Taxon.creation_changeset(%Taxon{}, taxon_attrs) |> Repo.insert()
    end
  end
end
