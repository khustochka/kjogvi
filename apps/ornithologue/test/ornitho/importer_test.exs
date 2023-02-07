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
                     "taxa will be deleted!",
                   fn ->
                     Importer.Test.NoTaxa.process_import()
                   end

      assert Ornitho.Find.Book.exists?(Importer.Test.NoTaxa.book_attributes()) == true
    end

    test "returns ok and updates the book if instructed to force" do
      _old_book = insert(:book, slug: "test", version: "no_taxa", name: "Old name")

      assert {:ok, _} = Importer.Test.NoTaxa.process_import(force: true)

      book =
        Ornitho.Find.Book.by_signature(
          Importer.Test.NoTaxa.slug(),
          Importer.Test.NoTaxa.version()
        )

      assert not is_nil(book)
      assert book.name == Importer.Test.NoTaxa.name()

      # TODO: when upsert is implemented
      # assert book.id == old_book.id
    end

    test "removes the taxa if instructed to force" do
      # ironic!
      book = insert(:book, slug: "test", version: "no_taxa")
      taxon = insert(:taxon, book: book)

      Importer.Test.NoTaxa.process_import(force: true)

      assert Ornitho.Repo.reload(taxon) == nil
    end

    test "returns ok if the book does not exist" do
      assert {:ok, _} = Importer.Test.NoTaxa.process_import()
    end

    test "creates the book if the book does not exist" do
      assert Ornitho.Find.Book.exists?(Importer.Test.NoTaxa.book_attributes()) == false
      assert {:ok, _} = Importer.Test.NoTaxa.process_import()

      book =
        Ornitho.Find.Book.by_signature(
          Importer.Test.NoTaxa.slug(),
          Importer.Test.NoTaxa.version()
        )

      assert %{
               slug: "test",
               version: "no_taxa",
               name: "Test book with no taxa",
               description: "This is a test book"
             } = book
    end

    @importer Importer.Demo.V1
    test "creates new taxa" do
      @importer.process_import()
      book = Ornitho.Find.Book.by_signature(@importer.slug(), @importer.version())
      taxa = Ecto.assoc(book, :taxa) |> Ornitho.Repo.all()
      assert length(taxa) > 0
    end
  end
end
