defmodule Kjogvi.Images.ImageTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Birding.Observation
  alias Kjogvi.Images.Image

  describe "observations_changeset/2" do
    test "accepts observations that share a card" do
      image = %Image{observations: []}
      observations = [%Observation{id: 1, card_id: 7}, %Observation{id: 2, card_id: 7}]

      changeset = Image.observations_changeset(image, observations)
      assert changeset.valid?
    end

    test "accepts a single observation" do
      image = %Image{observations: []}
      changeset = Image.observations_changeset(image, [%Observation{id: 1, card_id: 7}])
      assert changeset.valid?
    end

    test "accepts an empty list" do
      changeset = Image.observations_changeset(%Image{observations: []}, [])
      assert changeset.valid?
    end

    test "rejects observations from different cards" do
      image = %Image{observations: []}
      observations = [%Observation{id: 1, card_id: 7}, %Observation{id: 2, card_id: 9}]

      changeset = Image.observations_changeset(image, observations)
      refute changeset.valid?
      assert "must all belong to the same card" in errors_on(changeset).observations
    end
  end
end
