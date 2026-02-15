defmodule Ornitho.Query.BookTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true

  alias Ornitho.Query

  describe "select_signature/1" do
    test "selects only id, slug, and version" do
      insert(:book, slug: "ebird", version: "v2024", name: "eBird/Clements")

      [book] =
        Query.Book.base_book()
        |> Query.Book.select_signature()
        |> OrnithoRepo.all()

      assert book.slug == "ebird"
      assert book.version == "v2024"
      assert book.id
      # name is not selected
      refute book.name
    end
  end

  describe "by_id/2" do
    test "filters by book id" do
      book = insert(:book)
      _other = insert(:book)

      result =
        Query.Book.base_book()
        |> Query.Book.by_id(book.id)
        |> OrnithoRepo.all()

      assert length(result) == 1
      assert hd(result).id == book.id
    end
  end

  describe "touch_imported_at/1" do
    test "sets imported_at to current time" do
      book = insert(:book)
      assert is_nil(book.imported_at)

      {1, _} =
        Query.Book.base_book()
        |> Query.Book.by_id(book.id)
        |> Query.Book.touch_imported_at()
        |> OrnithoRepo.update_all([])

      updated = OrnithoRepo.reload(book)
      assert not is_nil(updated.imported_at)
    end
  end
end
