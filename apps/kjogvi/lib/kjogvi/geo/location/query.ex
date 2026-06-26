defmodule Kjogvi.Geo.Location.Query do
  @moduledoc """
  Queries for Locations.
  """

  @country_location_type :country
  @special_location_type :special
  @section_location_type :section

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
    :country_id,
    :subdivision1_id,
    :subdivision2_id,
    :city_id,
    :site_id
  ]

  # The level FK associations needed to render a location's display name
  # (`Location.long_name/2`).
  @level_assocs [:country, :subdivision1, :subdivision2, :city, :site]

  @doc """
  The level FK associations a location needs to render its display name.

  Use `preload_levels/1` to attach them to a query's `location`; this list is
  for the rarer cases that preload on a bare `Location` (or another assoc name).
  """
  def level_assocs, do: @level_assocs

  @doc """
  Preloads the level FK associations onto each checklist/observation's `location`.
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

  def exclude_specials(query) do
    from [..., l] in query,
      where: l.location_type != @special_location_type
  end

  def exclude_sections(query) do
    from [..., l] in query,
      where: l.location_type != @section_location_type
  end

  @doc """
  Folds a `Location.Filter` into `query`, applying each set refinement.
  """
  def apply_filter(query, %Location.Filter{} = filter) do
    query
    |> maybe_exclude_specials(filter.exclude_specials)
    |> maybe_exclude_sections(filter.exclude_sections)
  end

  defp maybe_exclude_specials(query, true), do: exclude_specials(query)
  defp maybe_exclude_specials(query, _), do: query

  defp maybe_exclude_sections(query, true), do: exclude_sections(query)
  defp maybe_exclude_sections(query, _), do: query

  @doc """
  Groups locations by `location_type`, selecting `{location_type, count}` pairs.
  """
  def count_by_type(query \\ Location) do
    from l in query,
      group_by: l.location_type,
      select: {l.location_type, count(l.id)}
  end

  def load_checklists_count(query) do
    from l in query,
      left_join: c in assoc(l, :checklists),
      group_by: l.id,
      select_merge: %{checklists_count: count(c.id)}
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
  Maps a location's own `location_type` to the descendant FK column that points
  back to it, or `nil` for levels (`section`) that are never an ancestor.
  """
  def descendant_fk(location_type), do: Map.get(@descendant_fk, location_type)

  @doc """
  Rewrites the level FKs of `location_id`'s descendants when the location moves
  from `old_type` to `new_type`.

  Descendants currently reference the location through the descendant FK column
  for its old level; this re-points them through the column for its new level
  (clearing the old one). The band invariant guarantees the new column is null on
  every descendant, so the move keeps each descendant's slot occupancy valid.

  Returns the number of rows updated. A move to/from `section` (no descendant
  column) touches nothing — a `section` has no descendants and is never an
  ancestor.
  """
  def move_descendants(location_id, old_type, new_type) do
    case {descendant_fk(old_type), descendant_fk(new_type)} do
      {nil, _} ->
        {0, nil}

      {old_fk, nil} ->
        from(l in Location, where: field(l, ^old_fk) == ^location_id)
        |> Repo.update_all(set: [{old_fk, nil}])

      {old_fk, new_fk} ->
        from(l in Location, where: field(l, ^old_fk) == ^location_id)
        |> Repo.update_all(set: [{old_fk, nil}, {new_fk, location_id}])
    end
  end

  @doc """
  Query selecting the ids of a special location's members plus all their
  descendants.

  A special is an amalgamation of member locations; a checklist counts toward it when
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

  @doc """
  Preloads each thing's `location` with the level FK associations its display
  name needs (`Location.long_name/2`).

  Delegates to `put_location_levels/1` so all five levels load in one query
  instead of one per association.
  """
  def preload_all_locations(things) do
    put_location_levels(things)
  end

  @doc """
  Attaches the level FK associations to each thing's `location` in a single
  query.

  Accepts checklists/observations/etc. that have a `:location` association (loaded or
  not — it is preloaded first if needed), then batches every level for every
  location through `put_levels/1`. Replaces the per-level preload (`country …
  site` = five queries) with one.
  """
  def put_location_levels(things) do
    things = Repo.preload(things, :location)

    locations =
      things
      |> List.wrap()
      |> Enum.map(& &1.location)
      |> Enum.reject(&is_nil/1)
      |> put_levels()
      |> Map.new(&{&1.id, &1})

    map_things(things, fn thing ->
      case thing.location do
        nil -> thing
        location -> %{thing | location: Map.fetch!(locations, location.id)}
      end
    end)
  end

  defp map_things(things, fun) when is_list(things), do: Enum.map(things, fun)
  defp map_things(thing, fun), do: fun.(thing)

  @doc """
  Attaches the five level FK associations (`country … site`) to each location in
  a single query.

  All five FKs reference the same `locations` table, so every ancestor any of the
  locations needs is fetched with one `id in ...` read and slotted back into the
  matching association — replacing Ecto's five per-association preload queries.
  Accepts a single location (or `nil`) or a list; the input locations must carry
  their level FK columns (e.g. `minimal_select/0`).
  """
  def put_levels(nil), do: nil

  def put_levels(locations) do
    list = List.wrap(locations)

    ids =
      list
      |> Enum.flat_map(&Location.ancestor_ids/1)
      |> Enum.uniq()

    by_id =
      from(l in minimal_select(), where: l.id in ^ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    placed = Enum.map(list, &put_level_assocs(&1, by_id))

    if is_list(locations), do: placed, else: hd(placed)
  end

  defp put_level_assocs(location, by_id) do
    Enum.reduce(Location.level_fk_by_level(), location, fn {assoc, fk}, loc ->
      %{loc | assoc => Map.get(by_id, Map.get(loc, fk))}
    end)
  end
end
