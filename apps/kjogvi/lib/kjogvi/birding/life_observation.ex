defmodule Kjogvi.Birding.LifeObservation do
  @moduledoc """
  Represents a lifelist observation: mixes attributes from the observation (taxon)
  and checklist (date, location)
  """

  use Kjogvi.Schema

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :observ_date, :date
    field :start_time, :time

    belongs_to(:species_page, Kjogvi.Pages.Species)

    belongs_to(:location, Kjogvi.Geo.Location)
    belongs_to(:checklist, Kjogvi.Birding.Checklist)
  end
end
