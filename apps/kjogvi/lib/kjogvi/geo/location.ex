defmodule Kjogvi.Geo.Location do
  @moduledoc """
  Location

  Columns starting with `cached_` are denormalized and store cached values that can
  be derived from `ancestry`. They are useful for selecting all locations for a region
  (country etc) but even more useful for building full location name.

  * cached_country_id: Country
  * cached_subdivision_id: Subdivision (state, province)
  * cached_city_id: City
  * cached_parent_id: This should only be set if parent name is a part of full name.
  * cached_public_location_id: For a private location, this is the closest public ancestor.

  TBD: For public location, should it be nil, or should it point to itself.

  Every time a location is changed (ancestry, is_private, location_type), these cached fields
  need to be recalculated for this location and all its former and new descendants.
  """

  use Kjogvi.Schema

  import Ecto.Changeset
  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

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
    belongs_to(:cached_public_location, Location)

    belongs_to(:cached_country, Location)
    belongs_to(:cached_parent, Location)
    belongs_to(:cached_city, Location)
    belongs_to(:cached_subdivision, Location)

    has_many(:cards, Kjogvi.Birding.Card)
    has_many(:observations, through: [:cards, :observations])

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

  def set_public_location_changeset(%Location{is_private: true} = location) do
    attrs = %{cached_public_location_id: raw_public_location(location).id}

    location
    |> cast(attrs, [:cached_public_location_id])
  end

  def set_public_location_changeset(%Location{} = location) do
    location
    |> change([])
  end

  def show_on_lifelist?(location) do
    not is_nil(location.public_index)
  end

  def full_name(%{is_patch: true, cached_parent: cached_parent} = location)
      when not is_nil(cached_parent) do
    [cached_parent.name_en, location.name_en]
    |> Enum.join(" - ")
  end

  def full_name(location) do
    location.name_en
  end

  def name_local_part(%{cached_city: cached_city} = location) do
    postfix =
      if is_nil(cached_city) do
        []
      else
        [cached_city.name_en]
      end

    [name_with_parent(location) | postfix]
    |> Enum.join(", ")
  end

  def name_administrative_part(location) do
    %{cached_subdivision: cached_subdivision, cached_country: country} = location

    [cached_subdivision, country]
    |> Enum.reject(&is_nil(&1))
    |> Enum.map_join(", ", & &1.name_en)
  end

  def long_name(location) do
    [name_local_part(location), name_administrative_part(location)]
    |> Enum.reject(&(is_nil(&1) || &1 == ""))
    |> Enum.join(", ")
  end

  def raw_public_location(%{is_private: false} = location) do
    location
  end

  def raw_public_location(%{ancestors: ancestors}) when is_list(ancestors) do
    ancestors
    |> Enum.reverse()
    |> Enum.find(fn loc ->
      !loc.is_private
    end)
  end

  def raw_public_location(location) do
    add_ancestors(location)
    |> raw_public_location()
  end

  def add_ancestors(location) do
    %{location | ancestors: ancestors(location)}
  end

  def ancestors(%{ancestry: ancestry} = _location) do
    from(l in Location,
      where: l.id in ^ancestry
    )
    |> Kjogvi.Repo.all()
    |> Enum.group_by(& &1.id)
    |> then(fn map ->
      ancestry
      |> Enum.map(fn id ->
        map[id] |> hd()
      end)
    end)
  end

  def preload_ancestors(locations) do
    ancestor_ids =
      locations
      |> Enum.flat_map(& &1.ancestry)
      |> Enum.uniq()

    all_ancestors =
      from(l in Location, where: l.id in ^ancestor_ids)
      |> Query.minimal_select()
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    locations
    |> Enum.map(fn location ->
      ancestors =
        location.ancestry
        |> Enum.map(fn id -> all_ancestors[id] end)

      %{location | ancestors: ancestors}
    end)
  end

  def to_flag_emoji(%{iso_code: nil}) do
    ""
  end

  def to_flag_emoji(%{iso_code: iso_code}) do
    iso_code
    |> String.upcase()
    |> String.to_charlist()
    |> Enum.map(&(&1 + 127_397))
    |> to_string()
  end

  defp name_with_parent(%{is_patch: true} = location) do
    full_name(location)
  end

  defp name_with_parent(%{cached_parent: nil} = location) do
    full_name(location)
  end

  defp name_with_parent(%{cached_parent: cached_parent} = location) do
    [full_name(location), cached_parent.name_en]
    |> Enum.join(", ")
  end
end
