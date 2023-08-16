defmodule Kjogvi.Schema.Card do
  use Kjogvi.Schema
  import Ecto.Changeset

  schema "cards" do
    field :observ_date, :date
    belongs_to(:location, Kjogvi.Schema.Location)

    field :effort_type, :string
    field :start_time, :time
    field :duration_minutes, :integer
    field :distance_kms, :float
    field :area_acres, :float

    field :biotope, :string
    field :weather, :string
    field :observers, :string

    field :notes, :string
    field :kml_url, :string
    field :motorless, :boolean, default: false

    field :legacy_autogenerated, :boolean, default: false
    field :resolved, :boolean, default: false

    field :ebird_id, :string

    timestamps()
  end

  @doc false
  def changeset(card, attrs) do
    card
    |> cast(attrs, [])
    |> validate_required([])
  end
end
