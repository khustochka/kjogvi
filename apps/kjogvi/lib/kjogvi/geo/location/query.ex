defmodule Kjogvi.Geo.Location.Query do
  @moduledoc """
  Queries for Locations.
  """

  @country_location_type :country
  @special_location_type :special

  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @minimal_select [
    :id,
    :slug,
    :name_en,
    :location_type,
    :iso_code,
    :is_private,
    :cached_parent_id,
    :cached_city_id,
    :cached_subdivision_id,
    :cached_country_id,
    :cached_public_location_id,
    :country_id,
    :subdivision1_id,
    :subdivision2_id,
    :city_id,
    :site_id,
    :ancestry
  ]

  # The cached ancestor associations needed to render a location's display
  # name (e.g. `Location.long_name/1`).
  @display_assocs [:cached_parent, :cached_city, :cached_subdivision, :cached_country]

  # The level FK associations needed to render a location's display name
  # (`Location.long_name_from_levels/1`).
  @level_assocs [:country, :subdivision1, :subdivision2, :city, :site]

  @doc """
  The cached ancestor associations a location needs to render its display name.

  Use `preload_display/1` to attach them to a query's `location`; this list is
  for the rarer cases that preload on a bare `Location` (or another assoc name).
  """
  def display_assocs, do: @display_assocs

  @doc """
  The level FK associations a location needs to render its display name.

  Use `preload_levels/1` to attach them to a query's `location`; this list is
  for the rarer cases that preload on a bare `Location` (or another assoc name).
  """
  def level_assocs, do: @level_assocs

  @doc """
  Preloads the display associations onto each card/observation's `location`.
  """
  def preload_display(query) do
    preload(query, location: ^@display_assocs)
  end

  @doc """
  Preloads the level FK associations onto each card/observation's `location`.
  """
  def preload_levels(query) do
    preload(query, location: ^@level_assocs)
  end

  def minimal_select(query \\ Location) do
    from(query)
    |> select(^@minimal_select)
  end

  def by_slug(query, slug) do
    from l in query, where: l.slug == ^slug
  end

  def only_public(query) do
    from l in query, where: l.is_private == false or is_nil(l.is_private)
  end

  @doc """
  Restricts to locations visible to a user: their own plus common ones.
  """
  def for_user(query, user) do
    from l in query, where: l.user_id == ^user.id or is_nil(l.user_id)
  end

  def countries(query) do
    from [..., l] in query,
      where: l.location_type == @country_location_type
  end

  def specials(query) do
    from [..., l] in query,
      where: l.location_type == @special_location_type
  end

  def load_cards_count(query) do
    from l in query,
      left_join: c in assoc(l, :cards),
      group_by: l.id,
      select_merge: %{cards_count: count(c.id)}
  end

  # Maps a location's own level to the descendant FK column that points back to it.
  # `section` is the lowest level and is never an ancestor, so it has no column.
  @descendant_fk %{
    country: :country_id,
    subdivision1: :subdivision1_id,
    subdivision2: :subdivision2_id,
    city: :city_id,
    site: :site_id
  }

  @doc """
  Query for `location` plus all of its descendants.

  A descendant is any location whose level FK for `location`'s own
  `location_type` points at it (descendants of a `subdivision1` are the rows with
  `subdivision1_id == location.id`); `location` itself is always included. A
  `section` (lowest level) or a location with no descendant column has only
  itself.
  """
  def child_locations(%{id: id, location_type: location_type}) do
    case Map.fetch(@descendant_fk, location_type) do
      {:ok, fk} ->
        from l in Location, where: field(l, ^fk) == ^id or l.id == ^id

      :error ->
        from l in Location, where: l.id == ^id
    end
  end

  # Level FK columns, top to bottom (mirrors `Location.level_fks/0`); used to
  # blank the slots below a location's own level when finding direct children.
  @level_fks ~w(country_id subdivision1_id subdivision2_id city_id site_id)a

  @doc """
  Query for the **direct** children of `location`: descendants whose deepest set
  level FK is `location` itself.

  A direct child has `location`'s descendant FK pointing at it and every level FK
  *below* `location`'s own level left null (so a `subdivision1`'s direct children
  are `subdivision2_id == id` rows with `city_id`/`site_id` null — not the cities
  nested further down). A `section` or unmapped type has no children.
  """
  def direct_children(%{id: id, location_type: location_type}) do
    case Map.fetch(@descendant_fk, location_type) do
      {:ok, fk} ->
        below = below_level_fks(fk)

        base = from l in Location, where: field(l, ^fk) == ^id

        Enum.reduce(below, base, fn lower_fk, query ->
          from l in query, where: is_nil(field(l, ^lower_fk))
        end)

      :error ->
        from l in Location, where: false
    end
  end

  # Level FK columns strictly below the given one.
  defp below_level_fks(fk) do
    @level_fks
    |> Enum.drop_while(&(&1 != fk))
    |> Enum.drop(1)
  end

  @doc """
  Query selecting the ids of a special location's members plus all their
  descendants.

  A special is an amalgamation of member locations; a card counts toward it when
  its location is a member or a descendant of one. Builds `child_locations/1` for
  each member (selecting ids) and unions them.
  """
  def special_descendant_ids(%{location_type: :special, id: id}) do
    members =
      from(l in Location,
        join: sl in "special_locations",
        on: sl.child_location_id == l.id,
        where: sl.parent_location_id == ^id,
        select: %{id: l.id, location_type: l.location_type}
      )
      |> Repo.all()

    case members do
      [] ->
        from l in Location, where: false, select: l.id

      [first | rest] ->
        Enum.reduce(rest, member_descendant_ids(first), fn member, acc ->
          union(acc, ^member_descendant_ids(member))
        end)
    end
  end

  defp member_descendant_ids(member) do
    child_locations(member)
    |> select([l], l.id)
  end

  def preload_all_locations(things) do
    level_preload = Enum.map(@level_assocs, &{&1, minimal_select()})

    things
    |> Repo.preload(location: {minimal_select(), level_preload})
    |> Enum.map(fn thing ->
      loc = Location.public_location_from_levels(thing.location)

      thing
      |> Map.put(:public_location, loc)
      |> Map.put(:public_location_id, loc && loc.id)
    end)
    |> preload_public_location_levels()
  end

  # The resolved public_location is the card location itself or one of its level
  # FK ancestors; preload the level assocs on those ancestors so their display
  # name can be built too.
  defp preload_public_location_levels(things) do
    public_locations =
      things
      |> Enum.map(& &1.public_location)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.id)
      |> Repo.preload(Enum.map(@level_assocs, &{&1, minimal_select()}))
      |> Map.new(&{&1.id, &1})

    Enum.map(things, fn thing ->
      case thing.public_location do
        nil -> thing
        loc -> Map.put(thing, :public_location, public_locations[loc.id])
      end
    end)
  end

  # Unused function. Use it to build proper ancestor preloading.
  def preload_location_ancestors(things) do
    # Only preload ancestors for private locations
    ancestor_loc_ids =
      things
      |> Enum.filter(fn lifer -> lifer.location.is_private end)
      |> Enum.flat_map(& &1.location.ancestry)
      |> Enum.uniq()

    loci =
      from(l in Location,
        where: l.id in ^ancestor_loc_ids,
        preload: [
          cached_parent: ^minimal_select(),
          cached_city: ^minimal_select(),
          cached_subdivision: ^minimal_select(),
          cached_country: ^minimal_select()
        ]
      )
      |> minimal_select()
      |> Repo.all()
      |> Enum.reduce(%{}, fn loc, acc -> Map.put(acc, loc.id, loc) end)

    things
    |> Enum.map(fn thing ->
      thing.location.ancestry
      |> Enum.map(fn id -> loci[id] end)
      |> then(fn ancestors ->
        put_in(thing.location.ancestors, ancestors)
      end)
    end)
  end
end
