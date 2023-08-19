defmodule Kjogvi.Birding.Location do
  use Kjogvi.Schema
  import Ecto.Changeset

  schema "locations" do
    field :slug, :string
    field :name_en, :string
    field :location_type, :string
    field :ancestry, {:array, :integer}, default: []
    field :iso_code, :string
    field :is_private, :boolean, default: false
    field :is_patch, :boolean, default: false
    field :is_5mr, :boolean, default: false
    field :lat, :decimal
    field :lon, :decimal
    field :public_index, :integer
    belongs_to(:cached_parent, Kjogvi.Birding.Location)
    belongs_to(:cached_city, Kjogvi.Birding.Location)
    belongs_to(:cached_subdivision, Kjogvi.Birding.Location)
    belongs_to(:cached_country, Kjogvi.Birding.Location)

    timestamps()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [])
    |> validate_required([])
  end
end
