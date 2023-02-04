defmodule OrnithoTest do
  @moduledoc false

  use Ornitho.RepoCase

  describe "Book creation" do
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
end
