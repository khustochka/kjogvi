defmodule Ornitho.Find.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  describe "exists?/2" do
    test "returns true if the book exists" do
      book = insert(:book)
      assert Ornitho.Find.Book.exists?(book.slug, book.version) == true
    end

    test "returns false if the book does not exist" do
      assert Ornitho.Find.Book.exists?("ebird", "v1") == false
    end
  end
end
