defmodule Ornitho.Schema.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Schema.Book

  describe "Book factory" do
    test "is valid" do
      book = insert(:book)

      assert Repo.all(Book) == [book]
    end
  end
end
