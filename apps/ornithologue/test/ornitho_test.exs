defmodule OrnithoTest do
  @moduledoc false

  use Ornitho.RepoCase

  describe ".create_book" do
    test "is not saved with empty slug" do
      book_attr = params_for(:book, slug: "")
      assert {:error, _} = Ornitho.create_book(book_attr)
    end

    test "is not saved with duplicate slug + version" do
      insert(:book, version: "v1")
      book_attr = params_for(:book, version: "v1")
      assert {:error, _} = Ornitho.create_book(book_attr)
    end
  end

  describe ".book_exists?" do
    test "returns true if the book exists" do
      book = insert(:book)
      assert Ornitho.book_exists?(book.slug, book.version) == true
    end

    test "returns true if the book does not exist" do
      assert Ornitho.book_exists?("ebird", "v1") == false
    end
  end

  describe "delete_book" do
    test "deletes the book if it exists" do
      book = insert(:book)
      assert Ornitho.delete_book(book.slug, book.version) == {1, nil}

      assert Ornitho.book_exists?(book.slug, book.version) == false
    end

    test "does nothing if the book does not exist" do
      assert Ornitho.book_exists?("ebird", "v1") == false
      assert Ornitho.delete_book("ebird", "v1") == {0, nil}
    end
  end

  describe "update_taxon" do
  end
end
