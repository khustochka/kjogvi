defmodule Ornitho.Schema.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Schema.Book

  describe "Book factory" do
    test "is valid" do
      book = insert(:book)

      assert OrnithoRepo.all(Book) == [book]
    end
  end

  describe "signature/1" do
    test "joins slug and version" do
      assert Book.signature(%Book{slug: "ebird", version: "v2024"}) == "ebird/v2024"
    end
  end
end
