defmodule Ornitho.ImporterTest do
  @moduledoc false

  use Ornitho.RepoCase

  alias Ornitho.Importer

  describe "process_import/2" do
    test "fails if importer module does not exist" do
      assert {:error, _} = Importer.process_import(Importer.Fake.V2)
    end

    test "returns error if the book exists (no force option)" do
      insert(:book, slug: "test", version: "no_taxa")

      assert Importer.process_import(Importer.Test.NoTaxa) ==
               {:error, :overwrite_not_allowed}

      assert Ornitho.Repo.exists?(Importer.Test.NoTaxa.book_query) == true
    end

    test "returns ok and updates the book if instructed to force" do
      old_book = insert(:book, slug: "test", version: "no_taxa", name: "Old name")

      assert {:ok, _} = Importer.process_import(Importer.Test.NoTaxa, force: true)
      book = Importer.Test.NoTaxa.book_query |> Ornitho.Repo.one()
      assert not is_nil(book)
      assert book.name == Importer.Test.NoTaxa.name()

      # TODO: when upsert is implemented
      # assert book.id == old_book.id
    end

    test "removes the taxa if instructed to force" do
      book = insert(:book, slug: "test", version: "no_taxa") # ironic!
      taxon = insert(:taxon, book: book)

      Importer.process_import(Importer.Test.NoTaxa, force: true)

      assert Ornitho.Repo.reload(taxon) == nil
    end

    test "returns ok if the book does not exist" do
      assert {:ok, _} = Importer.process_import(Importer.Test.NoTaxa)
    end

    test "creates the book if the book does not exist" do
      assert Ornitho.Repo.exists?(Importer.Test.NoTaxa.book_query()) == false
      assert {:ok, _} = Importer.process_import(Importer.Test.NoTaxa)

      book = Ornitho.Repo.one(Importer.Test.NoTaxa.book_query)

      assert %{
               slug: "test",
               version: "no_taxa",
               name: "Test book with no taxa",
               description: "This is a test book"
             } = book
    end
  end
end
