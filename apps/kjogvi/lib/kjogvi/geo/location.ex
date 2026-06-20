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

  # Ordered hierarchy levels, top to bottom.
  @hierarchy_levels ~w(country subdivision1 subdivision2 city site section)a

  # `special` sits outside the ordered hierarchy: no fixed level, any-rank parent.
  @location_types @hierarchy_levels ++ ~w(special)a

  # Level FK columns, top to bottom. `section` is the lowest level and never an
  # ancestor, so there is no `section_id`.
  @level_fks ~w(country_id subdivision1_id subdivision2_id city_id site_id)a

  # Maps each ancestor level to its FK column on a child.
  @level_fk_by_level Map.new(@level_fks, fn fk ->
                       {fk |> Atom.to_string() |> String.trim_trailing("_id") |> String.to_atom(),
                        fk}
                     end)

  schema "locations" do
    field :slug, :string
    field :name_en, :string
    field :location_type, Ecto.Enum, values: @location_types
    field :ancestry, {:array, :integer}, default: []
    field :iso_code, :string
    field :is_private, :boolean, default: false
    field :lat, :decimal
    field :lon, :decimal
    field :public_index, :integer
    field :extras, :map, default: %{}

    field :import_source, Ecto.Enum, values: Kjogvi.Types.ImportSource.values()

    belongs_to(:cached_public_location, Location)

    belongs_to(:cached_parent, Location)
    belongs_to(:cached_city, Location)
    belongs_to(:cached_subdivision, Location)
    belongs_to(:cached_country, Location)

    belongs_to(:country, Location)
    belongs_to(:subdivision1, Location)
    belongs_to(:subdivision2, Location)
    belongs_to(:city, Location)
    belongs_to(:site, Location)

    belongs_to(:user, Kjogvi.Accounts.User)

    has_many(:cards, Kjogvi.Birding.Card)
    has_many(:observations, through: [:cards, :observations])

    many_to_many :special_child_locations, Location,
      join_through: "special_locations",
      join_keys: [parent_location_id: :id, child_location_id: :id]

    many_to_many :special_parent_locations, Location,
      join_through: "special_locations",
      join_keys: [child_location_id: :id, parent_location_id: :id]

    timestamps()

    field :cards_count, :integer, virtual: true

    field :parent_id, :integer, virtual: true

    field :ancestors, :any,
      virtual: true,
      default: struct(Ecto.Association.NotLoaded, %{__field__: :ancestors})
  end

  @editable_fields ~w(
    slug
    name_en
    location_type
    iso_code
    is_private
    lat
    lon
    extras
    parent_id
    country_id
    subdivision1_id
    subdivision2_id
    city_id
    site_id
  )a

  def location_types, do: @location_types

  def hierarchy_levels, do: @hierarchy_levels

  def level_fks, do: @level_fks

  @doc """
  The location's ancestor ids, top to bottom: the non-null level FK values
  (`country_id … site_id`). Reads the FK columns directly — no preload needed.
  """
  def ancestor_ids(location) do
    @level_fks
    |> Enum.map(&Map.fetch!(location, &1))
    |> Enum.reject(&is_nil/1)
  end

  @doc """
  The id of the location's direct parent — its deepest set level FK — or `nil`
  for a top-level location. The inverse of `level_fks_from_parent/1`: editing
  this location and re-picking the same parent reproduces its level FKs.
  """
  def parent_id_from_levels(location) do
    location |> ancestor_ids() |> List.last()
  end

  @doc false
  def changeset(location, attrs) do
    location
    |> cast(attrs, @editable_fields)
    |> validate_required([
      :slug,
      :name_en,
      :is_private
    ])
    |> unique_constraint(:slug)
    |> put_level_fks_from_parent()
    |> validate_slot_occupancy()
  end

  # When a `parent_id` is present in the changeset, derive the five level FK
  # columns (and keep `ancestry` in sync) from the chosen parent. A nil
  # `parent_id` clears them. When `parent_id` was not cast at all (e.g. an edit
  # that touches only the name), the existing FKs are left untouched.
  defp put_level_fks_from_parent(changeset) do
    case fetch_change(changeset, :parent_id) do
      {:ok, nil} ->
        clear_level_fks(changeset)

      {:ok, parent_id} ->
        case Repo.get(__MODULE__, parent_id) do
          nil -> add_error(changeset, :parent_id, "does not exist")
          parent -> put_level_fks(changeset, parent)
        end

      :error ->
        changeset
    end
  end

  defp clear_level_fks(changeset) do
    changeset
    |> put_change(:ancestry, [])
    |> then(fn cs -> Enum.reduce(@level_fks, cs, &put_change(&2, &1, nil)) end)
  end

  defp put_level_fks(changeset, parent) do
    fks = level_fks_from_parent(parent)

    changeset
    |> put_change(:ancestry, ancestor_ids(parent) ++ [parent.id])
    |> then(fn cs -> Enum.reduce(@level_fks, cs, &put_change(&2, &1, Map.fetch!(fks, &1))) end)
  end

  @doc """
  The five level FK values a child would inherit from `parent`: the parent's own
  level FKs, plus the parent itself placed into the slot for its `location_type`
  (when the parent is one of the five ancestor-capable levels). A `section` or
  `special` parent contributes no slot of its own.
  """
  def level_fks_from_parent(parent) do
    base = Map.new(@level_fks, fn fk -> {fk, Map.get(parent, fk)} end)

    case Map.get(@level_fk_by_level, parent.location_type) do
      nil -> base
      fk -> Map.put(base, fk, parent.id)
    end
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

  @doc """
  Validates the level FK columns against the slot-occupancy invariant.

  For a location of a given `location_type`:

  - **Own-level-and-below null** — no FK may be set for the location's own level
    or any level below it.
  - **Belongs to a country** — every level below `country` must have `country_id`
    set; a location can't float with no ancestor. Intermediate levels are still
    skippable (a city may hang directly off a `country` or a `subdivision1`).
  - **Prefix-consistency** — each set ancestor's own higher-level FKs equal this
    location's, so the level FKs are a consistent subset of the ancestors'.

  `special` (and a location with no `location_type` yet) has no fixed level and
  is exempt. This is a pure single-row check (it loads the referenced ancestors
  only for prefix-consistency); it does not set any FKs.
  """
  def validate_slot_occupancy(changeset) do
    case get_field(changeset, :location_type) do
      nil -> changeset
      :special -> changeset
      location_type -> validate_levels(changeset, location_type)
    end
  end

  defp validate_levels(changeset, location_type) do
    set_levels =
      for {level, fk} <- @level_fk_by_level, not is_nil(get_field(changeset, fk)), do: level

    changeset
    |> validate_own_level_and_below(location_type, set_levels)
    |> validate_has_country(location_type)
    |> validate_prefix_consistency()
  end

  # No FK at the location's own level or below.
  defp validate_own_level_and_below(changeset, location_type, set_levels) do
    own_index = level_index(location_type)

    Enum.reduce(set_levels, changeset, fn level, acc ->
      if level_index(level) >= own_index do
        add_error(acc, @level_fk_by_level[level], "cannot be set for a #{location_type}")
      else
        acc
      end
    end)
  end

  # Every level below `country` must belong to a country.
  defp validate_has_country(changeset, :country), do: changeset

  defp validate_has_country(changeset, _location_type) do
    if is_nil(get_field(changeset, :country_id)) do
      add_error(changeset, :country_id, "can't be blank")
    else
      changeset
    end
  end

  # Each set ancestor's own higher-level FKs equal this location's.
  defp validate_prefix_consistency(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp validate_prefix_consistency(changeset) do
    set =
      for {level, fk} <- @level_fk_by_level, id = get_field(changeset, fk), do: {level, fk, id}

    ancestors =
      from(l in __MODULE__, where: l.id in ^Enum.map(set, fn {_, _, id} -> id end))
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.reduce(set, changeset, fn {level, fk, id}, acc ->
      case ancestors[id] do
        nil -> add_error(acc, fk, "does not exist")
        ancestor -> check_ancestor_prefix(acc, level, fk, ancestor)
      end
    end)
  end

  defp check_ancestor_prefix(changeset, level, fk, ancestor) do
    @hierarchy_levels
    |> Enum.take(level_index(level))
    |> Enum.reduce(changeset, fn higher, acc ->
      higher_fk = @level_fk_by_level[higher]

      if Map.get(ancestor, higher_fk) == get_field(acc, higher_fk) do
        acc
      else
        add_error(acc, higher_fk, "is inconsistent with #{fk}'s ancestry")
      end
    end)
  end

  defp level_index(level) do
    Enum.find_index(@hierarchy_levels, &(&1 == level))
  end

  def show_on_lifelist?(location) do
    not is_nil(location.public_index)
  end

  def full_name(location) do
    location.name_en
  end

  # Level FK ancestor associations, most-specific level first — the order their
  # names appear after the location's own name.
  @name_assocs ~w(site city subdivision2 subdivision1 country)a

  @doc """
  Builds a location's full display name from its level FK ancestors.

  The location's own `name_en`, followed by each set ancestor's `name_en` from
  the most specific level (`site`) up to `country`, joined by `", "`. Includes
  every segment regardless of privacy — for owner-facing contexts. Use
  `public_long_name_from_levels/1` where private segments must be hidden.
  Requires the level associations to be preloaded (`Query.preload_levels/1` /
  `Query.level_assocs/0`).
  """
  def long_name_from_levels(location) do
    [location | level_ancestors(location)]
    |> Enum.map_join(", ", & &1.name_en)
  end

  @doc """
  Like `long_name_from_levels/1`, but drops private segments (the location
  itself or any ancestor with `is_private`), so a private location's name never
  surfaces. For public-facing display.
  """
  def public_long_name_from_levels(location) do
    [location | level_ancestors(location)]
    |> Enum.reject(& &1.is_private)
    |> Enum.map_join(", ", & &1.name_en)
  end

  @doc """
  The nearest non-private location for public display: the location itself if it
  is public, otherwise its most-specific non-private level FK ancestor.

  Returns `nil` only if the location and all its ancestors are private. Requires
  the level associations to be preloaded (`Query.preload_levels/1` /
  `Query.level_assocs/0`).
  """
  def public_location_from_levels(location) do
    [location | level_ancestors(location)]
    |> Enum.find(&(!&1.is_private))
  end

  defp level_ancestors(location) do
    @name_assocs
    |> Enum.map(&Map.get(location, &1))
    |> Enum.reject(&(is_nil(&1) || match?(%Ecto.Association.NotLoaded{}, &1)))
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

  @doc """
  Derives virtual `parent_id` from `ancestry` (last element), for form editing.
  """
  def with_parent_id(%__MODULE__{ancestry: ancestry} = location) do
    %{location | parent_id: List.last(ancestry)}
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

  defp name_with_parent(%{cached_parent: nil} = location) do
    full_name(location)
  end

  defp name_with_parent(%{cached_parent: cached_parent} = location) do
    [full_name(location), cached_parent.name_en]
    |> Enum.join(", ")
  end
end
