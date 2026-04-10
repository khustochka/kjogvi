defmodule Kjogvi.Birding.Log.Entry do
  @moduledoc """
  A single log entry: a species (or multiple species) added to a specific list
  on a given date.

  - `type` is `:life` (first ever for this area) or `:year` (first in calendar year).
  - `area` is a `%Location{}` or `nil` for World.
  - `year` is set for `:year` entries, `nil` for `:life` entries.
  - `life_observations` are the `%LifeObservation{}` records that triggered this entry
    (one per species, the first observation for this area/year combo).
  """

  @type entry_type :: :life | :year

  @type t :: %__MODULE__{
          type: entry_type(),
          area: %Kjogvi.Geo.Location{} | nil,
          year: integer() | nil,
          life_observations: [%Kjogvi.Birding.LifeObservation{}],
          list_total: non_neg_integer() | nil
        }

  @enforce_keys [:type, :life_observations]
  defstruct [:type, :area, :year, :list_total, life_observations: []]
end
