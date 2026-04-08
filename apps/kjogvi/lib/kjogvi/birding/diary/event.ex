defmodule Kjogvi.Birding.Diary.Event do
  @moduledoc """
  A single diary event: a species (or multiple species) added to a specific list
  on a given date.

  - `type` is `:total` (first ever for this area) or `:year` (first in calendar year).
  - `area` is a `%Location{}` or `nil` for World.
  - `year` is set for `:year` events, `nil` for `:total` events.
  - `life_observations` are the `%LifeObservation{}` records that triggered this event
    (one per species, the first observation for this area/year combo).
  """

  @type event_type :: :total | :year

  @type t :: %__MODULE__{
          type: event_type(),
          area: %Kjogvi.Geo.Location{} | nil,
          year: integer() | nil,
          life_observations: [%Kjogvi.Birding.LifeObservation{}]
        }

  @enforce_keys [:type, :life_observations]
  defstruct [:type, :area, :year, life_observations: []]
end
