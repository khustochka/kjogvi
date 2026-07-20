defmodule Kjogvi.Birding.ObservationTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Birding.Observation

  describe "changeset/2" do
    test "valid with required taxon_key" do
      changeset =
        Observation.changeset(%Observation{}, %{"taxon_key" => "ebird/eBird_2023/bkcchi1"})

      assert changeset.valid?
    end

    test "invalid without taxon_key" do
      changeset = Observation.changeset(%Observation{}, %{})

      assert %{taxon_key: ["can't be blank"]} = errors_on(changeset)
    end

    test "casts breeding_code" do
      changeset =
        Observation.changeset(%Observation{}, %{
          "taxon_key" => "ebird/eBird_2023/bkcchi1",
          "breeding_code" => "CF"
        })

      assert changeset.valid?
      assert get_change(changeset, :breeding_code) == "CF"
    end

    test "casts ml_catalog_numbers" do
      changeset =
        Observation.changeset(%Observation{}, %{
          "taxon_key" => "ebird/eBird_2023/bkcchi1",
          "ml_catalog_numbers" => ["123456", "789012"]
        })

      assert changeset.valid?
      assert get_change(changeset, :ml_catalog_numbers) == ["123456", "789012"]
    end

    test "ml_catalog_numbers defaults to empty list" do
      observation = %Observation{}

      assert observation.ml_catalog_numbers == []
    end
  end
end
