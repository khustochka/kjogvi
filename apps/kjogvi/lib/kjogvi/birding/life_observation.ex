defmodule Kjogvi.Birding.LifeObservation do
  @moduledoc """
  Represents a lifelist observation: mixes attributes from the observation (taxon)
  and card (date, location)
  """

  use Kjogvi.Schema

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :taxon_key, :string
    field :observ_date, :date
    field :start_time, :time

    belongs_to(:location, Kjogvi.Birding.Location)
    belongs_to(:card, Kjogvi.Birding.Card)

    field :taxon, :map, virtual: true
    field :species, :map, virtual: true
  end
end
