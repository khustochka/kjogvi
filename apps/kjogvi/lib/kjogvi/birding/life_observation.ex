defmodule Kjogvi.Birding.LifeObservation do
  use Kjogvi.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :taxon_key, :string
    field :observ_date, :date
    field :start_time, :time

    belongs_to(:location, Kjogvi.Birding.Location)
    belongs_to(:card, Kjogvi.Birding.Card)

    field :taxon, :map, virtual: true
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [])
    |> validate_required([])
  end
end
