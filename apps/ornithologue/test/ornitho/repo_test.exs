defmodule Ornitho.RepoTest do
  @moduledoc false

  # async: false — the configured prefix is global application env.
  use Ornitho.RepoCase, async: false

  alias Ornitho.Finder
  alias Ornitho.Ops

  @prefix "ornitho_prefix_test"

  describe "without a configured prefix" do
    test "qualified/1 quotes the bare table name" do
      assert Ornitho.Repo.qualified("taxa") == ~s("taxa")
    end

    test "default_opts/1 returns options unchanged" do
      assert Ornitho.Repo.default_opts() == []
      assert Ornitho.Repo.default_opts(timeout: 100) == [timeout: 100]
    end
  end

  describe "with a configured prefix" do
    setup do
      Application.put_env(:ornithologue, :prefix, @prefix)
      on_exit(fn -> Application.delete_env(:ornithologue, :prefix) end)

      # Clone the tables into the prefixed schema; the sandbox rolls the DDL back.
      OrnithoRepo.query!(~s(CREATE SCHEMA "#{@prefix}"))

      for table <- ["books", "taxa"] do
        OrnithoRepo.query!(
          ~s{CREATE TABLE "#{@prefix}"."#{table}" (LIKE "public"."#{table}" INCLUDING ALL)}
        )
      end

      :ok
    end

    test "qualified/1 prepends the schema" do
      assert Ornitho.Repo.qualified("taxa") == ~s("#{@prefix}"."taxa")
    end

    test "default_opts/1 adds the prefix; explicit options win" do
      assert Ornitho.Repo.default_opts() == [prefix: @prefix]
      assert Ornitho.Repo.default_opts(prefix: "other") == [prefix: "other"]
    end

    test "writes and reads go to the prefixed schema" do
      assert {:ok, book} = Ops.Book.create(params_for(:book))

      assert count_in_schema(@prefix, "books") == 1
      assert count_in_schema("public", "books") == 0

      assert [found] = Finder.Book.all()
      assert found.id == book.id
    end

    test "preloads follow the prefix" do
      {:ok, book} = Ops.Book.create(params_for(:book))
      {:ok, taxon} = Ops.Taxon.create(book, params_for(:taxon, code: "comcuc"))

      found =
        Finder.Taxon.by_code(book, "comcuc")
        |> Finder.Taxon.with_book()

      assert found.id == taxon.id
      assert found.book.id == book.id
    end

    test "get_taxa_and_species/1 resolves keys from the prefixed schema" do
      {:ok, book} = Ops.Book.create(params_for(:book))
      {:ok, taxon} = Ops.Taxon.create(book, params_for(:taxon, code: "comcuc"))

      key = "/#{book.slug}/#{book.version}/comcuc"

      assert %{^key => found} = Ornithologue.get_taxa_and_species([key])
      assert found.id == taxon.id
    end

    test "link_parent_species/1 updates taxa in the prefixed schema" do
      {:ok, book} = Ops.Book.create(params_for(:book))

      {:ok, parent} = Ops.Taxon.create(book, params_for(:taxon, code: "comcuc"))

      {:ok, _child} =
        Ops.Taxon.create(
          book,
          params_for(:taxon,
            code: "comcuc1",
            category: "issf",
            extras: %{"parent_species_code" => "comcuc"}
          )
        )

      assert Ops.Taxon.link_parent_species(book.id) == {:ok, 1}
      assert Finder.Taxon.by_code(book, "comcuc1").parent_species_id == parent.id
    end
  end

  defp count_in_schema(schema, table) do
    %{rows: [[count]]} = OrnithoRepo.query!(~s{SELECT count(*) FROM "#{schema}"."#{table}"})
    count
  end
end
