defmodule Kjogvi.Geo.Location do
  @moduledoc """
  Location schema.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  alias Kjogvi.Geo.Location

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
    belongs_to(:country, Location)

    belongs_to(:cached_parent, Location)
    belongs_to(:cached_city, Location)
    belongs_to(:cached_subdivision, Location)

    has_many(:cards, Kjogvi.Birding.Card)

    many_to_many :special_child_locations, Location,
      join_through: "special_locations",
      join_keys: [parent_location_id: :id, child_location_id: :id]

    timestamps()

    field :cards_count, :integer, virtual: true
    field :ancestors, :any,
      virtual: true,
      default: struct(Ecto.Association.NotLoaded, %{__field__: :ancestors})
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

  def long_name(%{name_en: name, loc_type: "country"}) do
    name
  end

  def long_name(%{name_en: name, country: nil}) do
    name
  end

  def long_name(%{name_en: name, country: country}) do
    [name, country.name_en]
    |> Enum.join(", ")
  end

  def public_location(%{is_private: false} = location) do
    location
  end

  def public_location(%{ancestors: ancestors}) when is_list(ancestors) do
    ancestors
    |> Enum.reverse()
    |> Enum.find(fn loc ->
      !loc.is_private
    end)
  end
end
