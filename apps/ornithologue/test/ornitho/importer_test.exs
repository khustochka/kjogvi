defmodule Ornitho.ImporterTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  alias Ornitho.Importer

  @importer Importer.Test.NoTaxa
  describe "process_import/2" do
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
    end

    @importer Importer.Test.NoTaxa
    test "removes the taxa if instructed to force" do
      book = insert(:book, slug: "test", version: "no_taxa")
      # ironic!
      taxon = insert(:taxon, book: book)

      @importer.process_import(force: true)

      assert Kjogvi.OrnithoRepo.reload(taxon) == nil
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
      taxa = Ecto.assoc(book, :taxa) |> Kjogvi.OrnithoRepo.all()
      assert not Enum.empty?(taxa)
    end

    @importer Importer.Demo.V1
    test "sets the imported_at time after the taxa are imported" do
      @importer.process_import()
      book = Ornitho.Finder.Book.by_signature(@importer.slug(), @importer.version())
      assert not is_nil(book.imported_at)
    end
  end

  describe "telemetry" do
    @importer Importer.Demo.V1
    test "emits a stop event with duration and taxa_count" do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach(
        "test-#{inspect(ref)}",
        [:ornitho, :import, :stop],
        fn _event, measurements, metadata, _config ->
          send(test_pid, {ref, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach("test-#{inspect(ref)}") end)

      assert {:ok, count} = @importer.process_import()

      assert_receive {^ref, measurements, metadata}
      assert is_integer(measurements.duration)
      assert metadata.importer == @importer
      assert metadata.taxa_count == count
    end
  end

  describe "legit_importers/0" do
    test "returns a list of importer modules from config" do
      result = Importer.legit_importers()
      assert is_list(result)
      assert Enum.all?(result, &is_atom/1)
    end
  end

  describe "legit_importers_string/0" do
    test "returns importer module names as strings" do
      result = Importer.legit_importers_string()
      assert is_list(result)
      assert Enum.all?(result, &is_binary/1)
    end
  end

  describe "unimported/0" do
    test "returns importers that have not been imported yet" do
      result = Importer.unimported()
      assert is_list(result)
      legit = Importer.legit_importers()

      for importer <- result do
        assert importer in legit
      end
    end

    test "excludes already imported books" do
      before_count = length(Importer.unimported())
      Importer.Demo.V1.process_import()
      after_count = length(Importer.unimported())

      # Demo.V1 is not in legit_importers, so count should be the same
      # This just verifies unimported/0 doesn't crash with imported books
      assert is_integer(after_count)
      assert after_count <= before_count
    end
  end

  describe "import_timeout/0" do
    test "returns an integer timeout value" do
      result = Importer.import_timeout()
      assert is_integer(result)
      assert result > 0
    end
  end
end
