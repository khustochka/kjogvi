defmodule Kjogvi.Birding.CardTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Birding.Card

  describe "changeset/2" do
    test "valid with required fields" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1
        })

      assert changeset.valid?
    end

    test "invalid without observ_date" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1
        })

      assert %{observ_date: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without location_id" do
      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "effort_type" => "STATIONARY",
          "user_id" => 1
        })

      assert %{location_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid without effort_type" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "user_id" => 1
        })

      assert %{effort_type: ["can't be blank"]} = errors_on(changeset)
    end

    test "casts optional fields" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "TRAVEL",
          "user_id" => 1,
          "start_time" => "08:30:00",
          "duration_minutes" => 60,
          "distance_kms" => 3.5,
          "notes" => "Sunny morning",
          "motorless" => true
        })

      assert changeset.valid?
      assert get_change(changeset, :start_time) == ~T[08:30:00]
      assert get_change(changeset, :duration_minutes) == 60
      assert get_change(changeset, :distance_kms) == 3.5
      assert get_change(changeset, :notes) == "Sunny morning"
      assert get_change(changeset, :motorless) == true
    end

    test "casts nested observations" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1,
          "observations" => %{
            "0" => %{"taxon_key" => "ebird/eBird_2023/bkcchi1"}
          }
        })

      assert changeset.valid?
    end

    test "filters out blank observations" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1,
          "observations" => %{
            "0" => %{"taxon_key" => "ebird/eBird_2023/bkcchi1"},
            "1" => %{"taxon_key" => "", "quantity" => "", "notes" => "", "private_notes" => ""}
          }
        })

      assert changeset.valid?
      # Only the non-blank observation should remain
      obs_changes = get_change(changeset, :observations)
      assert length(obs_changes) == 1
    end

    test "filters out completely nil blank observations" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1,
          "observations" => %{
            "0" => %{"taxon_key" => "ebird/eBird_2023/bkcchi1"},
            "1" => %{
              "taxon_key" => nil,
              "quantity" => nil,
              "notes" => nil,
              "private_notes" => nil
            }
          }
        })

      assert changeset.valid?
      obs_changes = get_change(changeset, :observations)
      assert length(obs_changes) == 1
    end

    test "updates observations_order when filtering blanks" do
      location = insert(:location)

      changeset =
        Card.changeset(%Card{}, %{
          "observ_date" => "2024-05-10",
          "location_id" => location.id,
          "effort_type" => "STATIONARY",
          "user_id" => 1,
          "observations" => %{
            "0" => %{"taxon_key" => "ebird/eBird_2023/bkcchi1"},
            "1" => %{"taxon_key" => "", "quantity" => "", "notes" => "", "private_notes" => ""}
          },
          "observations_order" => ["0", "1"]
        })

      assert changeset.valid?
    end

    test "passes through non-map attrs unchanged" do
      changeset = Card.changeset(%Card{}, %{})

      refute changeset.valid?
      assert %{observ_date: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "effort_types/0" do
    test "returns all effort types" do
      types = Card.effort_types()

      assert "STATIONARY" in types
      assert "TRAVEL" in types
      assert "AREA" in types
      assert "INCIDENTAL" in types
      assert "HISTORICAL" in types
      assert length(types) == 5
    end
  end
end
