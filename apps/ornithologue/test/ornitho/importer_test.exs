defmodule Ornitho.ImporterTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  alias Ornitho.Importer

  @importer Importer.Test.NoTaxa
  describe "process_import/2" do
    test "raises if the book exists (no force option)" do
      insert(:book, slug: "test", version: "no_taxa")

      assert_raise RuntimeError,
                   "A book for importer Ornitho.Importer.Test.NoTaxa already exists, to force overwrite " <>
                     "it pass [force: true] (or --force in a Mix task. Please note that in this case all " <>
                     "taxa will be deleted!",
                   fn ->
                     @importer.process_import()
                   end

      assert Ornitho.Finder.Book.exists?(@importer.slug, @importer.version) == true
    end

    @importer Importer.Test.NoTaxa
    test "returns ok and updates the book if instructed to force" do
      _old_book = insert(:book, slug: "test", version: "no_taxa", name: "Old name")

      assert {:ok, _} = @importer.process_import(force: true)

      book =
        Ornitho.Finder.Book.by_signature(
          @importer.slug(),
          @importer.version()
        )

      assert not is_nil(book)
      assert book.name == @importer.name()

      # TODO: when upsert is implemented
      # assert book.id == old_book.id
    end

    @importer Importer.Test.NoTaxa
    test "removes the taxa if instructed to force" do
      book = insert(:book, slug: "test", version: "no_taxa")
      # ironic!
      taxon = insert(:taxon, book: book)

      @importer.process_import(force: true)

      assert Ornitho.TestRepo.reload(taxon) == nil
    end

    @importer Importer.Test.NoTaxa
    test "returns ok if the book does not exist" do
      assert {:ok, _} = @importer.process_import()
    end

    @importer Importer.Test.NoTaxa
    test "creates the book if the book does not exist" do
      assert Ornitho.Finder.Book.exists?(@importer.slug, @importer.version) == false
      assert {:ok, _} = @importer.process_import()

      book =
        Ornitho.Finder.Book.by_signature(
          @importer.slug(),
          @importer.version()
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
      book = Ornitho.Finder.Book.by_signature(@importer.slug(), @importer.version())
      taxa = Ecto.assoc(book, :taxa) |> Ornitho.TestRepo.all()
      assert length(taxa) > 0
    end

    @importer Importer.Demo.V1
    test "sets the imported_at time after the taxa are imported" do
      @importer.process_import()
      book = Ornitho.Finder.Book.by_signature(@importer.slug(), @importer.version())
      assert not is_nil(book.imported_at)
    end
  end
end
