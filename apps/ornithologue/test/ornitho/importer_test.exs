defmodule Ornitho.ImporterTest do
  @moduledoc false

  use Ornitho.RepoCase

  alias Ornitho.Importer

  describe "process_import/2" do
    test "raises if the book exists (no force option)" do
      insert(:book, slug: "test", version: "no_taxa")

      assert_raise RuntimeError,
        "A book for importer Ornitho.Importer.Test.NoTaxa already exists, to force overwrite " <>
        "it pass [force: true] (or --force in a Mix task. Please note that in this case all " <>
        "taxa will be deleted!", fn ->
        Importer.Test.NoTaxa.process_import()
      end

      assert Ornitho.book_exists?(Importer.Test.NoTaxa.book_map()) == true
    end

    test "returns ok and updates the book if instructed to force" do
      _old_book = insert(:book, slug: "test", version: "no_taxa", name: "Old name")

      assert {:ok, _} = Importer.Test.NoTaxa.process_import(force: true)
      book = Importer.Test.NoTaxa.book_query |> Ornitho.Repo.one()
      assert not is_nil(book)
      assert book.name == Importer.Test.NoTaxa.name()

      # TODO: when upsert is implemented
      # assert book.id == old_book.id
    end

    test "removes the taxa if instructed to force" do
      book = insert(:book, slug: "test", version: "no_taxa") # ironic!
      taxon = insert(:taxon, book: book)

      Importer.Test.NoTaxa.process_import(force: true)

      assert Ornitho.Repo.reload(taxon) == nil
    end

    test "returns ok if the book does not exist" do
      assert {:ok, _} = Importer.Test.NoTaxa.process_import()
    end

    test "creates the book if the book does not exist" do
      assert Ornitho.book_exists?(Importer.Test.NoTaxa.book_map()) == false
      assert {:ok, _} = Importer.Test.NoTaxa.process_import()

      book = Ornitho.Repo.one(Importer.Test.NoTaxa.book_query())

      assert %{
               slug: "test",
               version: "no_taxa",
               name: "Test book with no taxa",
               description: "This is a test book"
             } = book
    end
  end
end
