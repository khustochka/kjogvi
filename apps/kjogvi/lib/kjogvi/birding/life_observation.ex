defmodule Kjogvi.Birding.LifeObservation do
  @moduledoc """
  Represents a lifelist observation: mixes attributes from the observation (taxon)
  and card (date, location)
  """

  use Kjogvi.Schema

  alias Kjogvi.Pages.Species

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :cached_species_key, :string
    field :observ_date, :date
    field :start_time, :time

    belongs_to(:location, Kjogvi.Geo.Location)
    belongs_to(:card, Kjogvi.Birding.Card)

    field :cached_species, :map, virtual: true
    embeds_one :species, Species

    belongs_to(:public_location, Kjogvi.Geo.Location)
  end
end
