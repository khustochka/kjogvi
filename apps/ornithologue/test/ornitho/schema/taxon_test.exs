defmodule Ornitho.Schema.TaxonTest do
  @moduledoc false

  use Ornitho.RepoCase
  alias Ornitho.Schema.Taxon

  describe "Taxon" do
    test "is saved" do
      tx = insert(:taxon)

      assert [taxon] = Repo.all(Taxon)

      assert taxon.name_sci == tx.name_sci
    end

    test "same scientific names in different books" do
      error = try do
        _tx1 = insert(:taxon)
        _tx2 = insert(:taxon)
        nil
      rescue
        e -> e
      end
      assert error == nil
    end
  end
end
