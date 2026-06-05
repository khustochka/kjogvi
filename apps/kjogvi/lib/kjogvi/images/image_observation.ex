defmodule Kjogvi.Images.ImageObservation do
  @moduledoc """
  Join table between images and observations.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  schema "image_observations" do
    belongs_to :image, Kjogvi.Images.Image
    belongs_to :observation, Kjogvi.Birding.Observation

    timestamps()
  end

  @doc false
  def changeset(image_observation, attrs) do
    image_observation
    |> cast(attrs, [:image_id, :observation_id])
    |> validate_required([:image_id, :observation_id])
    |> unique_constraint([:image_id, :observation_id])
  end
end
