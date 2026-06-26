defmodule Kjogvi.Images.ImageTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Birding.Observation
  alias Kjogvi.Images.Image

  describe "legacy_changeset/2" do
    @valid_attrs %{slug: "pileated", user_id: 1, legacy_url: "https://old.example.com/a.jpg"}

    test "is valid with a legacy_url, slug and user" do
      changeset = Image.legacy_changeset(%Image{}, @valid_attrs)
      assert changeset.valid?
    end

    test "sets the storage backend to \"legacy\"" do
      changeset = Image.legacy_changeset(%Image{}, @valid_attrs)
      assert get_change(changeset, :storage_backend) == "legacy"
    end

    test "assigns a token" do
      changeset = Image.legacy_changeset(%Image{}, @valid_attrs)
      assert get_change(changeset, :token)
    end

    test "requires a legacy_url" do
      changeset = Image.legacy_changeset(%Image{}, Map.delete(@valid_attrs, :legacy_url))
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).legacy_url
    end

    test "does not cast a file" do
      changeset =
        Image.legacy_changeset(%Image{}, Map.put(@valid_attrs, :file, "anything"))

      refute Map.has_key?(changeset.changes, :file)
    end
  end

  describe "observations_changeset/2" do
    test "accepts observations that share a checklist" do
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

    test "sets multi_species when more than one observation is attached" do
      image = %Image{observations: []}
      observations = [%Observation{id: 1, card_id: 7}, %Observation{id: 2, card_id: 7}]

      changeset = Image.observations_changeset(image, observations)
      assert Ecto.Changeset.get_change(changeset, :multi_species) == true
    end

    test "clears multi_species for a single observation" do
      image = %Image{observations: [], multi_species: true}
      changeset = Image.observations_changeset(image, [%Observation{id: 1, card_id: 7}])
      assert Ecto.Changeset.get_change(changeset, :multi_species) == false
    end

    test "rejects an empty list" do
      changeset = Image.observations_changeset(%Image{observations: []}, [])
      refute changeset.valid?
      assert "can't be empty" in errors_on(changeset).observations
    end

    test "rejects observations from different cards" do
      image = %Image{observations: []}
      observations = [%Observation{id: 1, card_id: 7}, %Observation{id: 2, card_id: 9}]

      changeset = Image.observations_changeset(image, observations)
      refute changeset.valid?
      assert "must all belong to the same checklist" in errors_on(changeset).observations
    end
  end
end
