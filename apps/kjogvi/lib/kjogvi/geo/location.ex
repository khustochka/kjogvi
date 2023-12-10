defmodule Kjogvi.Geo.Location do
  @moduledoc """
  Location schema.
  """

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
    belongs_to(:country, Kjogvi.Geo.Location)

    belongs_to(:cached_parent, Kjogvi.Geo.Location)
    belongs_to(:cached_city, Kjogvi.Geo.Location)
    belongs_to(:cached_subdivision, Kjogvi.Geo.Location)

    has_many(:cards, Kjogvi.Birding.Card)

    timestamps()

    field :cards_count, :integer, virtual: true
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, [])
    |> validate_required([
      :slug,
      :name_en,
      :ancestry,
      :is_private,
      :is_patch,
      :is_5mr
    ])
  end
end
