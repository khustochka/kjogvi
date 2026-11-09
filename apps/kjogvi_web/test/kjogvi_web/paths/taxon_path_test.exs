defmodule KjogviWeb.Paths.TaxonPathTest do
  use ExUnit.Case, async: true

  import KjogviWeb.Paths.TaxonPath

  @taxon %{book: %{slug: "ebird", version: "v2024"}, code: "houspa"}

  describe "my_taxon_path/2" do
    test "first page" do
      assert my_taxon_path(@taxon) == "/my/taxa/ebird/v2024/houspa"
      assert my_taxon_path(@taxon, 1) == "/my/taxa/ebird/v2024/houspa"
    end

    test "later page" do
      assert my_taxon_path(@taxon, 3) == "/my/taxa/ebird/v2024/houspa/page/3"
    end
  end
end
