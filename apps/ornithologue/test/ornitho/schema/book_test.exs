defmodule Ornitho.Schema.BookTest do
  @moduledoc false

  use Ornitho.RepoCase
  alias Ornitho.Schema.Book

  describe "Book" do
    test "is saved" do
      book = insert(:book)

      assert Repo.all(Book) == [book]
    end
  end
end
