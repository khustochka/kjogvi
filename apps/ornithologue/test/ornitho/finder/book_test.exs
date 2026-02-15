defmodule Ornitho.Finder.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  describe "exists?/2" do
    test "returns true if the book exists" do
      book = insert(:book)
      assert Ornitho.Finder.Book.exists?(book.slug, book.version) == true
    end

    test "returns false if the book does not exist" do
      assert Ornitho.Finder.Book.exists?("ebird", "v1") == false
    end
  end

  describe "all/0" do
    test "returns all books" do
      insert(:book)
      insert(:book)

      assert length(Ornitho.Finder.Book.all()) == 2
    end
  end

  describe "all_signatures/0" do
    test "returns slug and version pairs for all books" do
      book1 = insert(:book, slug: "ebird", version: "v2024")
      book2 = insert(:book, slug: "ioc", version: "v14")

      signatures = Ornitho.Finder.Book.all_signatures()
      assert [book1.slug, book1.version] in signatures
      assert [book2.slug, book2.version] in signatures
    end
  end

  describe "all_importers/0" do
    test "returns importer strings for all books" do
      insert(:book, importer: "Elixir.Ornitho.Importer.Demo.V1")
      insert(:book, importer: "Elixir.Ornitho.Importer.Demo.V2")

      importers = Ornitho.Finder.Book.all_importers()
      assert "Elixir.Ornitho.Importer.Demo.V1" in importers
      assert "Elixir.Ornitho.Importer.Demo.V2" in importers
    end
  end

  describe "by_signature/2" do
    test "returns the book matching slug and version" do
      book = insert(:book, slug: "ebird", version: "v2024")

      result = Ornitho.Finder.Book.by_signature("ebird", "v2024")
      assert result.id == book.id
    end

    test "returns nil when no match" do
      assert Ornitho.Finder.Book.by_signature("nonexistent", "v1") == nil
    end
  end

  describe "by_signature!/2" do
    test "returns the book matching slug and version" do
      book = insert(:book, slug: "ebird", version: "v2024")

      result = Ornitho.Finder.Book.by_signature!("ebird", "v2024")
      assert result.id == book.id
    end

    test "raises when no match" do
      assert_raise Ecto.NoResultsError, fn ->
        Ornitho.Finder.Book.by_signature!("nonexistent", "v1")
      end
    end
  end
end
