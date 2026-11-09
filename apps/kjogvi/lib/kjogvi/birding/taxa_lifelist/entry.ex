defmodule Kjogvi.Birding.TaxaLifelist.Entry do
  @moduledoc """
  First record of a taxon on the taxa lifelist: the observation's taxon and its
  checklist's date and location. `taxon` is the resolved `Ornitho.Schema.Taxon`
  (the parent species on the species-level list).
  """

  use Kjogvi.Schema

  @type t() :: %__MODULE__{}

  @primary_key false
  embedded_schema do
    field :id, :integer
    field :taxon_key, :string
    field :observ_date, :date
    field :start_time, :time
    field :taxon, :any, virtual: true

    belongs_to(:location, Kjogvi.Geo.Location)
    belongs_to(:checklist, Kjogvi.Birding.Checklist)
  end
end
