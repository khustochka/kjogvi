defmodule Kjogvi.Kjogvi.Schema.Observation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "observations" do


    timestamps()
  end

  @doc false
  def changeset(observation, attrs) do
    observation
    |> cast(attrs, [])
    |> validate_required([])
  end
end
