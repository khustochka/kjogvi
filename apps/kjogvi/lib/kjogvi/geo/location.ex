defmodule Kjogvi.Geo.Location do
  @moduledoc """
  Location

  A location's place in the hierarchy is held in the level FK columns
  `country_id … site_id` (one per ordered level above `section`). They name the
  ancestor at each level directly, so selecting a region (all locations under a
  country, etc.) and building a full display name are simple FK reads — see
  `ancestor_ids/1` and `long_name/2`.
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

  # The levels that can be a regular hierarchy parent: every level that has an FK
  # slot (so a child can point at it). `section` is the lowest level and never an
  # ancestor; `special` is a member-amalgamation, not a hierarchy parent.
  @hierarchy_parent_types Map.keys(@level_fk_by_level)

  # Types that may only exist as common locations (`nil` owner): the top of the
  # hierarchy, shared across all users. A user-belonging location (a set
  # `user_id`) may not be one of these — see `validate_user_owned_type/1`.
  @common_only_types ~w(country subdivision1)a

  schema "locations" do
    field :slug, :string
    field :name_en, :string
    field :location_type, Ecto.Enum, values: @location_types
    field :iso_code, :string
    field :is_private, :boolean, default: false
    field :lat, :decimal
    field :lon, :decimal
    field :public_index, :integer
    field :extras, :map, default: %{}

    field :import_source, Ecto.Enum, values: Kjogvi.Types.ImportSource.values()

    belongs_to(:country, Location)
    belongs_to(:subdivision1, Location)
    belongs_to(:subdivision2, Location)
    belongs_to(:city, Location)
    belongs_to(:site, Location)

    belongs_to(:user, Kjogvi.Accounts.User)

    has_one(:ebird_location, Kjogvi.Geo.EbirdLocation)

    has_many(:checklists, Kjogvi.Birding.Checklist)
    has_many(:observations, through: [:checklists, :observations])

    many_to_many :special_child_locations, Location,
      join_through: "special_locations",
      join_keys: [parent_location_id: :id, child_location_id: :id],
      on_replace: :delete

    many_to_many :special_parent_locations, Location,
      join_through: "special_locations",
      join_keys: [child_location_id: :id, parent_location_id: :id]

    timestamps()

    field :checklists_count, :integer, virtual: true

    field :parent_id, :integer, virtual: true
  end

  @editable_fields ~w(
    slug
    name_en
    location_type
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
  Maps each ancestor level (`:country … :site`) to its FK column on a child
  (`:country_id …`). The level association of the same name holds the row that FK
  points at.
  """
  def level_fk_by_level, do: @level_fk_by_level

  @doc """
  Whether the location can be a hierarchy parent — i.e. have sub-locations.
  `section` (the lowest level) and `special` (outside the hierarchy) cannot.
  """
  def hierarchy_parent?(location) do
    location.location_type in @hierarchy_parent_types
  end

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
    changeset =
      location
      |> cast(attrs, @editable_fields)
      |> validate_required([
        :slug,
        :name_en,
        :location_type,
        :is_private
      ])
      |> validate_length(:slug, min: 3)
      |> validate_format(:slug, ~r/\A[a-z0-9_-]+\z/,
        message: "must contain only lowercase letters, digits, underscores and hyphens"
      )
      # An all-digits slug would be ambiguous with a year in Lifelist URL.
      |> validate_format(:slug, ~r/\D/, message: "can't be only digits")
      # Slugs are unique per owner; common locations (`nil` user) share a
      # partial index keeping their slugs globally unique.
      |> unique_constraint(:slug, name: :locations_user_id_slug_index)
      |> unique_constraint(:slug, name: :locations_common_slug_index)

    {changeset, parent} = put_level_fks_from_parent(changeset)

    changeset
    |> validate_slot_occupancy(parent)
    |> validate_location_type_change()
  end

  # When a `parent_id` is present in the changeset, derive the five level FK
  # columns from the chosen parent. A nil `parent_id` clears them. When
  # `parent_id` was not cast at all (e.g. an edit that touches only the name),
  # the existing FKs are left untouched.
  #
  # Returns `{changeset, parent}` — the loaded parent is threaded into
  # `validate_slot_occupancy/2` so it can skip re-querying the ancestors whose
  # consistency the parent already guarantees (see `validate_prefix_consistency`).
  defp put_level_fks_from_parent(changeset) do
    case fetch_change(changeset, :parent_id) do
      {:ok, nil} ->
        {clear_level_fks(changeset), nil}

      {:ok, parent_id} ->
        case Repo.get(__MODULE__, parent_id) do
          nil ->
            {add_error(changeset, :parent_id, "does not exist"), nil}

          %{location_type: type} when type not in @hierarchy_parent_types ->
            {add_error(changeset, :parent_id, "cannot be a #{type}"), nil}

          parent ->
            {put_level_fks(changeset, parent), parent}
        end

      :error ->
        {changeset, nil}
    end
  end

  defp clear_level_fks(changeset) do
    Enum.reduce(@level_fks, changeset, &put_change(&2, &1, nil))
  end

  defp put_level_fks(changeset, parent) do
    fks = level_fks_from_parent(parent)

    Enum.reduce(@level_fks, changeset, &put_change(&2, &1, Map.fetch!(fks, &1)))
  end

  @doc """
  The five level FK values a child would inherit from `parent`: the parent's own
  level FKs, plus the parent itself placed into the slot for its `location_type`.

  Only a hierarchy-level parent (`country … site`) reaches here — `changeset/2`
  rejects `section` and `special` parents before this is called.
  """
  def level_fks_from_parent(parent) do
    fk = Map.fetch!(@level_fk_by_level, parent.location_type)

    @level_fks
    |> Map.new(fn fk -> {fk, Map.get(parent, fk)} end)
    |> Map.put(fk, parent.id)
  end

  @doc """
  Changeset replacing a special location's member list.

  Requires `special_child_locations` to be preloaded. A `special` may not itself
  be a member (which also rules out self-membership). When the special sits under
  a parent (its deepest set level FK), every member must belong to that parent,
  directly or through deeper levels; a parentless special accepts members
  anywhere. Later re-parenting a member can silently break this — that's on the
  user, no re-check happens.
  """
  def special_members_changeset(location, members) do
    location
    |> change()
    |> put_assoc(:special_child_locations, members)
    |> validate_members_not_special(members)
    |> validate_members_within_parent(location, members)
  end

  defp validate_members_not_special(changeset, members) do
    case Enum.filter(members, &(&1.location_type == :special)) do
      [] ->
        changeset

      specials ->
        names = Enum.map_join(specials, ", ", & &1.name_en)
        add_error(changeset, :special_child_locations, "cannot include specials: #{names}")
    end
  end

  # The level FKs are denormalized, so "belongs to the parent at any depth" is a
  # single column read: the member's FK at the parent's level names the parent.
  defp validate_members_within_parent(changeset, special, members) do
    case deepest_level_fk(special) do
      nil ->
        changeset

      {fk, parent_id} ->
        case Enum.reject(members, &(Map.fetch!(&1, fk) == parent_id)) do
          [] ->
            changeset

          outside ->
            names = Enum.map_join(outside, ", ", & &1.name_en)

            add_error(
              changeset,
              :special_child_locations,
              "must be under the special's parent: #{names}"
            )
        end
    end
  end

  # The location's deepest set level FK as `{column, id}`, or nil when top-level.
  defp deepest_level_fk(location) do
    @level_fks
    |> Enum.reverse()
    |> Enum.find_value(fn fk ->
      case Map.fetch!(location, fk) do
        nil -> nil
        id -> {fk, id}
      end
    end)
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
  def validate_slot_occupancy(changeset, parent \\ nil) do
    case get_field(changeset, :location_type) do
      nil -> changeset
      :special -> changeset
      location_type -> validate_levels(changeset, location_type, parent)
    end
  end

  defp validate_levels(changeset, location_type, parent) do
    set_levels =
      for {level, fk} <- @level_fk_by_level, not is_nil(get_field(changeset, fk)), do: level

    changeset
    |> validate_own_level_and_below(location_type, set_levels)
    |> validate_has_country(location_type)
    |> validate_prefix_consistency(parent)
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
  defp validate_prefix_consistency(%Ecto.Changeset{valid?: false} = changeset, _parent),
    do: changeset

  # When the level FKs were derived from a loaded parent, prefix-consistency
  # holds by construction: the parent is always a hierarchy level (changeset/2
  # rejects section/special), so the FKs are its own already-validated FKs plus
  # the parent in its slot, and every ancestor's higher FKs transitively equal
  # this location's. No query needed.
  defp validate_prefix_consistency(changeset, %__MODULE__{}), do: changeset

  defp validate_prefix_consistency(changeset, nil) do
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

  @doc """
  Validates that a `location_type` change stays within the band left open by the
  location's existing relatives:

      (highest set parent level) < new level < (lowest existing child level)

  The **upper bound** (parents) is already enforced by `validate_slot_occupancy/1`:
  the level FKs derived from the chosen parent would put an FK at the new level or
  below, which slot occupancy rejects. This adds the **lower bound** — a location
  may demote to level L only if every existing child stays strictly below L, i.e.
  it has no child at L or any level above it (a child at-or-above the new level
  would end up at-or-above its own ancestor). A brand-new location has no
  children, so this is a no-op on create.

  `special` and a not-yet-set `location_type` are exempt — they have no fixed
  level. The check runs only when `location_type` actually changes to a hierarchy
  level on an already-persisted location.
  """
  def validate_location_type_change(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  def validate_location_type_change(
        %{data: %{__meta__: %{state: :loaded}} = location} = changeset
      ) do
    case fetch_change(changeset, :location_type) do
      {:ok, new_type} when new_type in @hierarchy_levels ->
        validate_no_child_at_or_above(changeset, location, new_type)

      _ ->
        changeset
    end
  end

  def validate_location_type_change(changeset), do: changeset

  defp validate_no_child_at_or_above(changeset, location, new_type) do
    new_index = level_index(new_type)

    # A child must stay strictly below the new level; one at the new level or
    # above (lower-or-equal index) would collide with — or outrank — its ancestor.
    blocking_levels = Enum.take(@hierarchy_levels, new_index + 1)

    has_blocking_child =
      Query.child_locations(location)
      |> where([l], l.id != ^location.id)
      |> where([l], l.location_type in ^blocking_levels)
      |> Repo.exists?()

    if has_blocking_child do
      add_error(
        changeset,
        :location_type,
        "cannot change to #{new_type}: a sub-location is at that level or above"
      )
    else
      changeset
    end
  end

  @doc """
  Rejects a `location_type` that may only exist as a common location (`country`,
  `subdivision1`) when the location is user-belonging (its `user_id` is set).

  These top-of-hierarchy types are shared across all users and are populated by
  the ISO 3166 import (`Kjogvi.Geo.Import`); a user creates locations below them.
  The changeset itself is ownership-agnostic, so the context applies this after
  `user_id` is known (`Kjogvi.Geo.create_location/2`, `update_location/3`).
  """
  def validate_user_owned_type(changeset) do
    user_id = get_field(changeset, :user_id)
    type = get_field(changeset, :location_type)

    if not is_nil(user_id) and type in @common_only_types do
      add_error(changeset, :location_type, "can't be #{type} for a user location")
    else
      changeset
    end
  end

  @doc """
  The `location_type`s a user may pick for their own locations: every type except
  the common-only ones (`country`, `subdivision1`).
  """
  def user_assignable_types do
    @location_types -- @common_only_types
  end

  def show_on_lifelist?(location) do
    not is_nil(location.public_index)
  end

  # Level FK ancestor associations, most-specific level first — the order their
  # names appear after the location's own name.
  @name_assocs ~w(site city subdivision2 subdivision1 country)a

  @doc """
  Builds a location's full display name from its level FK ancestors: the
  location's own `name_en`, followed by each set ancestor's `name_en` from the
  most specific level (`site`) up to `country`, joined by `", "`.

  The first argument is the visibility:

    * `:private` — include every segment regardless of privacy. For owner-facing
      contexts, where the owner may see their own private location names.
    * `:public` — drop private segments (the location itself or any ancestor with
      `is_private`), so a private location's name never surfaces. For
      public-facing display. Note a resolved public location can still carry a
      private ancestor (privacy is not downward-closed), so this filtering is
      required even on an already-public location.

  Options:

    * `:relative_to` — a location whose segments are already implied by the
      surrounding context (e.g. a lifelist filtered by Manitoba). Drops that
      location and all its ancestors from the name, so a row need not repeat
      ", Manitoba, Canada". Levels are skippable, so the cutoff is by ancestor id
      (not rank). When every segment would be dropped (the location *is*
      `:relative_to`), falls back to the location's own `name_en`.

  Requires the level associations to be loaded (`Query.put_levels/1` /
  `Query.put_location_levels/1`).
  """
  def long_name(visibility, location, opts \\ []) do
    Enum.map_join(name_segments(visibility, location, opts), ", ", & &1.name_en)
  end

  @doc """
  The visible name segment locations behind `long_name/3` — the location's own
  name followed by its level FK ancestors (most specific first), with the same
  visibility and `:relative_to` filtering applied.

  Returns the list of `%Location{}` segments rather than the joined string, so
  callers can render each segment individually (e.g. as a link). See
  `long_name/3` for the argument and option semantics.
  """
  def name_segments(visibility, location, opts \\ []) do
    visible = visible_segments([location | level_ancestors(location)], visibility)

    case drop_relative_to(visible, opts[:relative_to]) do
      # Only `:relative_to` truncating away every visible segment falls back to
      # the bare name; visibility filtering alone keeps the empty result.
      [] when visible != [] -> [location]
      segments -> segments
    end
  end

  defp drop_relative_to(segments, nil), do: segments

  defp drop_relative_to(segments, %__MODULE__{} = relative_to) do
    cutoff = MapSet.new([relative_to.id | ancestor_ids(relative_to)])
    Enum.reject(segments, &MapSet.member?(cutoff, &1.id))
  end

  defp visible_segments(segments, :private), do: segments
  defp visible_segments(segments, :public), do: Enum.reject(segments, & &1.is_private)

  defp level_ancestors(location) do
    @name_assocs
    |> Enum.map(&Map.get(location, &1))
    |> Enum.reject(&(is_nil(&1) || match?(%Ecto.Association.NotLoaded{}, &1)))
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
end
