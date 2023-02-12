defmodule Ornitho.Ops.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Ops

  describe "book creation" do
    test "is saved with valid attributes" do
      book_attr = params_for(:book)
      assert {:ok, _} = Ops.Book.create(book_attr)
    end

    test "is not saved with empty slug" do
      book_attr = params_for(:book, slug: "")
      assert {:error, _} = Ops.Book.create(book_attr)
    end

    test "is not saved with duplicate slug + version" do
      insert(:book, version: "v1")
      book_attr = params_for(:book, version: "v1")
      assert {:error, _} = Ops.Book.create(book_attr)
    end
  end

  describe "book deletion" do
    test "deletes the book if it exists" do
      book = insert(:book)
      assert Ops.Book.delete(book.slug, book.version) == {1, nil}

      assert Ornitho.Find.Book.exists?(book.slug, book.version) == false
    end

    test "does nothing if the book does not exist" do
      assert Ornitho.Find.Book.exists?("ebird", "v1") == false
      assert Ops.Book.delete("ebird", "v1") == {0, nil}
    end
  end
end
