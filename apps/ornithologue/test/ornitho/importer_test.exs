defmodule Ornitho.ImporterTest do
  @moduledoc false

  use Ornitho.RepoCase

  alias Ornitho.Importer

  @importer Importer.Demo.V1

  describe "prepare_repo/2" do
    test "returns error if the book exists" do
      insert(:book, slug: "demo", version: "v1")

      assert Importer.prepare_repo(@importer, force: false) ==
               {:error, :overwrite_not_allowed}

      assert Ornitho.Repo.exists?(@importer.book_query) == true
    end

    test "returns ok if the book does not exist" do
      assert {:ok, _} = Importer.prepare_repo(@importer, force: false)
    end

    test "returns ok and removes the book if instructed to force" do
      insert(:book, slug: "demo", version: "v1")

      assert {:ok, _} = Importer.prepare_repo(@importer, force: true)
      assert Ornitho.Repo.exists?(@importer.book_query) == false
    end

    test "removes the book and taxa if instructed to force" do
      book = insert(:book, slug: "demo", version: "v1")
      taxon = insert(:taxon, book: book)

      Importer.prepare_repo(@importer, force: true)

      assert Ornitho.Repo.reload(book) == nil
      assert Ornitho.Repo.reload(taxon) == nil
    end
  end

  describe "process_import/2" do
    test "fails if importer module does not exist" do
      assert {:error, _} = Importer.process_import(Importer.Fake.V2, force: false)
    end
  end
end
