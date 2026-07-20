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

    test "invalid with an unknown breeding_code" do
      changeset =
        Observation.changeset(%Observation{}, %{
          "taxon_key" => "ebird/eBird_2023/bkcchi1",
          "breeding_code" => "BOGUS"
        })

      assert %{breeding_code: ["is invalid"]} = errors_on(changeset)
    end

    test "valid without a breeding_code" do
      changeset =
        Observation.changeset(%Observation{}, %{"taxon_key" => "ebird/eBird_2023/bkcchi1"})

      assert changeset.valid?
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

  describe "breeding_codes/0" do
    test "returns {code, label} pairs" do
      codes = Observation.breeding_codes()

      assert {"NY", "Nest with Young"} in codes
      assert {"A", "Agitated Behavior"} in codes
      assert {"F", "Flyover"} in codes
    end

    test "labels carry no trailing evidence-category parenthetical" do
      for {_code, label} <- Observation.breeding_codes() do
        refute label =~ ~r/\((Confirmed|Probable|Possible|Observed)/
      end
    end
  end
end
