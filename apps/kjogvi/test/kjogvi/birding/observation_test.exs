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

  describe "changeset/2 import provenance" do
    test "ignores ebird_obs_id and import_source" do
      changeset =
        Observation.changeset(%Observation{}, %{
          "taxon_key" => "ebird/eBird_2023/bkcchi1",
          "ebird_obs_id" => "OBS123",
          "import_source" => "ebird"
        })

      assert changeset.valid?
      assert get_change(changeset, :ebird_obs_id) == nil
      assert get_change(changeset, :import_source) == nil
    end
  end

  describe "import_changeset/2" do
    test "casts ebird_obs_id and import_source on top of the regular changeset" do
      changeset =
        Observation.import_changeset(%Observation{}, %{
          taxon_key: "ebird/eBird_2023/bkcchi1",
          quantity: "2",
          ebird_obs_id: "OBS123",
          import_source: :ebird
        })

      assert changeset.valid?
      assert get_change(changeset, :ebird_obs_id) == "OBS123"
      assert get_change(changeset, :import_source) == :ebird
      assert get_change(changeset, :quantity) == "2"
    end

    test "still requires taxon_key" do
      changeset = Observation.import_changeset(%Observation{}, %{import_source: :ebird})

      assert %{taxon_key: ["can't be blank"]} = errors_on(changeset)
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
