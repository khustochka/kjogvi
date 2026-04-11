defmodule Kjogvi.Birding.Log.Entry do
  @moduledoc """
  A single log entry: a species (or multiple species) added to a specific list
  on a given date.

  - `type` is `:life` (first ever for this area) or `:year` (first in calendar year).
  - `area` is a `%Location{}` or `nil` for World.
  - `year` is set for `:year` entries, `nil` for `:life` entries.
  - `life_observations` are the `%LifeObservation{}` records that triggered this entry
    (one per species, the first observation for this area/year combo).
  - `covered_areas` are secondary `:life` scopes this entry also satisfies for
    every species in `life_observations` — e.g. a world lifer that is also a
    new species for Manitoba. Each element is `{%Location{}, list_total}` where
    `list_total` is the total for that area after the latest species in this
    entry was added. Only populated when all species in the entry share the
    same set of covered areas (that's how they came to be grouped together).
  """

  @type entry_type :: :life | :year
  @type covered_area :: {%Kjogvi.Geo.Location{}, non_neg_integer()}

  @type t :: %__MODULE__{
          type: entry_type(),
          area: %Kjogvi.Geo.Location{} | nil,
          year: integer() | nil,
          life_observations: [%Kjogvi.Birding.LifeObservation{}],
          list_total: non_neg_integer() | nil,
          covered_areas: [covered_area()]
        }

  @enforce_keys [:type, :life_observations]
  defstruct [:type, :area, :year, :list_total, life_observations: [], covered_areas: []]
end
