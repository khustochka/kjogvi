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

  describe "with_taxa_count/0" do
    test "returns books with the number of taxa" do
      book1 = insert(:book)
      book2 = insert(:book)
      insert(:taxon, book: book1)
      insert(:taxon, book: book1)

      result = Ornitho.Finder.Book.with_taxa_count()
      assert {book1, %{taxa_count: 2}} in result
      assert {book2, %{taxa_count: 0}} in result
    end
  end

  describe "taxa_count" do
    test "returns the number of taxa in the book" do
      book1 = insert(:book)
      book2 = insert(:book)
      insert(:taxon, book: book1)
      insert(:taxon, book: book1)

      assert Ornitho.Finder.Book.taxa_count(book1) == 2
      assert Ornitho.Finder.Book.taxa_count(book2) == 0
    end
  end
end
