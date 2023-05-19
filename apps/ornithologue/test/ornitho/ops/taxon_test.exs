defmodule Ornitho.Ops.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase, async: true
  alias Ornitho.Ops

  describe "creating one taxon" do
    test "success" do
      book = insert(:book)
      attrs = params_for(:taxon)

      assert {:ok, _} = Ops.Taxon.create(book, attrs)
    end

    test "create/2 will return error if taxon is not valid" do
      book = insert(:book)
      attrs = params_for(:taxon, name_sci: "")

      assert {:error, _} = Ops.Taxon.create(book, attrs)
    end

    test "create!/2 will raise if taxon is not valid" do
      book = insert(:book)
      attrs = params_for(:taxon, name_sci: "")

      assert_raise Ecto.InvalidChangesetError, fn ->
        Ops.Taxon.create!(book, attrs)
      end
    end
  end
end
