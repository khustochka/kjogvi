defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

  alias Kjogvi.Accounts.User
  alias Kjogvi.Util
  alias Kjogvi.Repo
  alias __MODULE__.Location

  # Maps each hierarchy level to its rank, so tree siblings can be ordered top
  # level first (subdivision2 before city before site …) rather than purely by name.
  @level_rank Location.hierarchy_levels() |> Enum.with_index() |> Map.new()

  def get_countries do
    Location
    |> Location.Query.countries()
    |> Repo.all()
  end

  @doc """
  Common (shared, non user-owned) countries ordered by name — used to build the
  country select on the profile form.
  """
  def list_common_countries do
    Location
    |> Location.Query.only_common()
    |> Location.Query.countries()
    |> Location.Query.order_by_name()
    |> Repo.all()
  end

  @doc """
  A map of `location_type => count` over all locations, used to report what the
  ISO 3166 import produced (or what already occupies the table).
  """
  def location_counts_by_type do
    Location.Query.count_by_type()
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Like `location_counts_by_type/0`, restricted to common locations — the rows
  the dataset dump/restore operates on.
  """
  def common_location_counts_by_type do
    Location
    |> Location.Query.only_common()
    |> Location.Query.count_by_type()
    |> Repo.all()
    |> Map.new()
  end

  @doc """
  Returns hierarchical context for the lifelist location filter, as a strict
  drill-down: World lists the countries, selecting a country reveals its
  subdivisions, and so on one level at a time.

  `locations` is the area's filter universe — the `country`/`subdivision1` rows
  that have observations (see `Birding.Lifelist.location_ids/1`). Given a
  selected location (or nil for "World"), returns, each ordered by name:
  - `ancestors` — filter locations in the selected location's level FK chain
  - `siblings` — filter locations sharing the selected location's effective filter parent (the countries, at World)
  - `children` — filter locations whose effective filter parent is the selected location (empty at World)

  Hierarchy is read from each location's level FK columns (`country_id …
  site_id`); the "effective filter parent" is the deepest of those ancestors
  that is itself in `locations`, so non-filter intermediaries are skipped.
  """
  def get_lifelist_location_context(locations, selected_location) do
    all = Enum.sort_by(locations, & &1.name_en)
    lifelist_ids = MapSet.new(all, & &1.id)

    selected_id = selected_location && selected_location.id
    my_parent = selected_location && effective_lifelist_parent(selected_location, lifelist_ids)

    ancestors =
      case selected_location do
        nil ->
          []

        loc ->
          ancestor_ids = Location.ancestor_ids(loc)

          all
          |> Enum.filter(&(&1.id in ancestor_ids))
          |> Enum.sort_by(fn a -> Enum.find_index(ancestor_ids, &(&1 == a.id)) end)
      end

    siblings =
      Enum.filter(all, fn loc ->
        loc.id != selected_id && effective_lifelist_parent(loc, lifelist_ids) == my_parent
      end)

    # Only the selected location's own children — at World nothing is selected,
    # so there are none; drilling into a country reveals its subdivisions.
    children =
      case selected_id do
        nil ->
          []

        id ->
          Enum.filter(all, fn loc ->
            effective_lifelist_parent(loc, lifelist_ids) == id
          end)
      end

    %{ancestors: ancestors, siblings: siblings, children: children}
  end

  # Returns the nearest lifelist ancestor id — the deepest of the location's
  # level FK ancestors that is present in the lifelist set.
  defp effective_lifelist_parent(location, lifelist_ids) do
    location
    |> Location.ancestor_ids()
    |> Enum.reverse()
    |> Enum.find(&MapSet.member?(lifelist_ids, &1))
  end

  @doc """
  Builds the full location tree for the private locations index: the
  `current_user`'s own locations plus the common ancestors they hang under.

  Own locations are fetched first; only the common rows their level FKs name are
  then loaded, so the untouched shared scaffold is never read. Every location is
  placed under its direct parent — the deepest ancestor named by its level FKs
  (`Location.parent_id_from_levels/1`) — so the tree follows the real hierarchy
  to any depth, with skipped levels handled (a site with no city hangs off its
  subdivision). Specials are excluded (they render separately). Siblings are
  ordered hierarchy level first, then name. Level FK associations are preloaded
  for display names.

  Returns a list of uniform nodes, recursively:

      [%{location: %Location{}, children_count: 1, children: [%{location: ..., ...}]}]

  A node's `children` are the locations whose direct parent is that node; a leaf
  has an empty `children` list.
  """
  def location_tree(%{current_user: %User{} = user}) do
    own =
      Location
      |> Location.Query.owned_by(user)
      |> Location.Query.exclude_specials()
      |> Repo.all()

    ancestor_ids =
      own
      |> Enum.flat_map(&Location.ancestor_ids/1)
      |> Enum.uniq()

    commons =
      Location
      |> Location.Query.by_ids(ancestor_ids)
      |> Location.Query.only_common()
      |> Repo.all()

    (own ++ commons)
    |> Location.Query.put_levels()
    |> build_tree()
  end

  @doc """
  Returns the countries of the common (unowned) scaffold as unloaded tree nodes —
  `%{location: location, children_count: n, children: nil}`, ordered by name.

  `children_count` counts each country's direct common children (specials
  excluded), so the tree knows whether to offer expansion; the children
  themselves are fetched on demand with `common_location_children/1`. Used by
  the admin common-locations index.
  """
  def common_location_roots do
    Location
    |> Location.Query.only_common()
    |> Location.Query.countries()
    |> Repo.all()
    |> unloaded_nodes()
  end

  @doc """
  Loads the direct common children of location `parent_id` as unloaded tree
  nodes (same shape as `common_location_roots/0`), specials excluded, ordered
  hierarchy level first, then name.
  """
  def common_location_children(parent_id) do
    Repo.get!(Location, parent_id)
    |> Location.Query.direct_children()
    |> Location.Query.only_common()
    |> Location.Query.exclude_specials()
    |> Repo.all()
    |> unloaded_nodes()
  end

  def common_locations_count do
    common_scaffold()
    |> Repo.aggregate(:count)
  end

  defp unloaded_nodes(locations) do
    counts = Location.Query.direct_children_counts(common_scaffold(), locations)

    locations
    |> sort_siblings()
    |> Enum.map(&%{location: &1, children_count: Map.get(counts, &1.id, 0), children: nil})
  end

  defp common_scaffold do
    Location
    |> Location.Query.only_common()
    |> Location.Query.exclude_specials()
  end

  defp build_tree(locations) do
    by_parent = Enum.group_by(locations, &Location.parent_id_from_levels/1)
    present_ids = MapSet.new(locations, & &1.id)

    # Roots: locations with no parent (countries) or whose parent isn't shown.
    roots =
      Enum.reject(locations, fn loc ->
        parent_id = Location.parent_id_from_levels(loc)
        parent_id && MapSet.member?(present_ids, parent_id)
      end)

    build_nodes(roots, by_parent)
  end

  defp build_nodes(locations, by_parent) do
    locations
    |> sort_siblings()
    |> Enum.map(fn location ->
      children = build_nodes(Map.get(by_parent, location.id, []), by_parent)
      %{location: location, children_count: length(children), children: children}
    end)
  end

  defp sort_siblings(locations) do
    Enum.sort_by(
      locations,
      &{Map.get(@level_rank, &1.location_type, 99), Util.String.strip_diacritics(&1.name_en)}
    )
  end

  def get_child_locations(parent_id) do
    parent = Repo.get!(Location, parent_id)

    Location.Query.child_locations(parent)
    |> where([l], l.id != ^parent_id)
    |> Location.Query.load_checklists_count()
    |> where([l], l.location_type != :special or is_nil(l.location_type))
    |> Repo.all()
  end

  def get_locations_by_ids([]), do: []

  def get_locations_by_ids(ids) do
    from(l in Location, where: l.id in ^ids)
    |> Repo.all()
  end

  def get_locations do
    Location
    |> Location.Query.load_checklists_count()
    |> Repo.all()
  end

  @doc """
  Returns member locations for a special location, or an empty list if not special.
  """
  def special_member_locations(%Location{location_type: :special} = location) do
    location
    |> Repo.preload(special_child_locations: from(l in Location, order_by: l.name_en))
    |> Map.get(:special_child_locations)
  end

  def special_member_locations(%Location{}), do: []

  @doc """
  Replaces the member list of a special location with the locations named by
  `member_ids`.

  Members are resolved among the locations `scope` may see, so ids outside the
  scope are dropped. A `special` may not be a member, and when the special sits
  under a parent every member must belong to that parent (directly or through
  deeper levels) — see `Location.special_members_changeset/2`.

  Returns `{:error, :forbidden}` when the scope may not modify the location.
  """
  def update_special_members(scope, %Location{location_type: :special} = location, member_ids) do
    if User.owns?(scope.current_user, location) do
      members =
        scoped_locations(scope)
        |> Location.Query.by_ids(member_ids)
        |> Repo.all()

      location
      |> Repo.preload(:special_child_locations)
      |> Location.special_members_changeset(members)
      |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  def get_specials(scope) do
    scoped_locations(scope)
    |> Location.Query.specials()
    |> Repo.all()
    |> Location.Query.put_levels()
  end

  def location_by_slug(slug) do
    Location
    |> Location.Query.by_slug(slug)
    |> Repo.one()
  end

  def location_by_slug_scope(scope, slug) do
    scoped_locations(scope)
    |> Location.Query.by_slug(slug)
    |> Repo.one()
  end

  def common_location_by_slug(slug) do
    Location
    |> Location.Query.only_common()
    |> Location.Query.by_slug(slug)
    |> Repo.one()
  end

  @doc """
  Searches locations visible to `scope`, restricting the base query to what the
  scope may see before delegating to `Kjogvi.Search.Location`.

  A `Location.Filter` may be passed via the `:filter` option to further narrow the
  base query by purpose (e.g. hide `special` locations); it defaults to a blank,
  no-op filter.
  """
  def search_locations(scope, term, opts \\ []) do
    {filter, opts} = Keyword.pop(opts, :filter, %Location.Filter{})

    scoped_locations(scope)
    |> Location.Query.apply_filter(filter)
    |> Kjogvi.Search.Location.search_locations(term, opts)
  end

  @doc """
  Searches the common (unowned) locations dataset, specials excluded — the
  admin common-locations index search.
  """
  def search_common_locations(term) do
    Location
    |> Location.Query.only_common()
    |> Location.Query.exclude_specials()
    |> Kjogvi.Search.Location.search_locations(term)
  end

  @doc """
  Autocomplete entrypoint: `search_locations/3` with the `filter` ahead of `term`,
  so the `{module, fun, args}` form used by `LocationAutocomplete` (which appends
  `term` last) can carry a `Location.Filter`.
  """
  def suggest_locations(scope, %Location.Filter{} = filter, term) do
    search_locations(scope, term, filter: filter)
  end

  # The base query of locations a scope may see.
  defp scoped_locations(%{area: :admin}), do: Location

  defp scoped_locations(%{area: :private, current_user: user}) do
    Location |> Location.Query.for_user(user)
  end

  defp scoped_locations(_scope) do
    Location |> Location.Query.only_public()
  end

  def checklists_count(location_id) do
    from(c in Kjogvi.Birding.Checklist,
      where: c.location_id == ^location_id,
      select: count(c.id)
    )
    |> Repo.one()
  end

  @doc """
  Returns the direct children of a location — the descendants whose deepest set
  level FK is this location — ordered by name.
  """
  def direct_children(%Location{} = location) do
    location
    |> Location.Query.direct_children()
    |> Location.Query.order_by_name()
    |> Repo.all()
  end

  @doc """
  Like `direct_children/1`, but restricted to common (unowned) children — the
  admin dataset view, where users' personal locations don't belong.
  """
  def common_direct_children(%Location{} = location) do
    location
    |> Location.Query.direct_children()
    |> Location.Query.only_common()
    |> Location.Query.order_by_name()
    |> Repo.all()
  end

  @doc """
  Returns a location's ancestors, top to bottom (country first), read from its
  level FK columns.
  """
  def ancestor_locations(%Location{} = location) do
    ancestor_ids = Location.ancestor_ids(location)
    by_id = Map.new(get_locations_by_ids(ancestor_ids), &{&1.id, &1})

    Enum.map(ancestor_ids, &by_id[&1])
  end

  def children_count(location_id) do
    location = Repo.get!(Location, location_id)

    Location.Query.child_locations(location)
    |> where([l], l.id != ^location_id)
    |> select([l], count(l.id))
    |> Repo.one()
  end

  @doc """
  Returns a changeset for creating or editing a location.
  """
  def change_location(%Location{} = location, attrs \\ %{}) do
    Location.changeset(location, attrs)
  end

  @doc """
  Creates a location owned by the scope's `current_user`. In the `:admin` area
  the location is created common (no owner) instead — that's how curated
  common locations enter the dataset.
  """
  def create_location(scope, attrs) do
    %Location{}
    |> Location.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, owner_id(scope))
    |> put_hide_flag(scope, attrs)
    |> Location.validate_user_owned_type()
    |> Location.validate_common_ancestry()
    |> Repo.insert()
  end

  # `hide_flag` is admin-only; only cast it from the `:admin` area.
  defp put_hide_flag(changeset, %{area: :admin}, attrs),
    do: Location.put_hide_flag(changeset, attrs)

  defp put_hide_flag(changeset, _scope, _attrs), do: changeset

  defp owner_id(%{area: :admin}), do: nil
  defp owner_id(scope), do: scope.current_user && scope.current_user.id

  @doc """
  Updates a location.

  When the `location_type` changes, the descendants' level FKs are cascaded in
  the same transaction so they keep pointing at this location through the column
  for its new level.

  Returns `{:error, :forbidden}` when the scope may not modify the location.
  Ownership (`user_id`) is not editable, so it is never changed here.
  """
  def update_location(scope, %Location{} = location, attrs) do
    if can_manage?(scope, location) do
      Repo.transact(fn -> update_and_cascade(scope, location, attrs) end)
    else
      {:error, :forbidden}
    end
  end

  # The owner may manage their own locations; the `:admin` area may manage
  # common (unowned) ones — but not anyone's personal locations.
  defp can_manage?(%{area: :admin}, %Location{user_id: nil}), do: true
  defp can_manage?(scope, location), do: User.owns?(scope.current_user, location)

  # Updates the location and, when its `location_type` changed, cascades the
  # descendants' level FKs onto the new level column. Runs inside the
  # `update_location/3` transaction.
  defp update_and_cascade(scope, location, attrs) do
    old_type = location.location_type

    changeset =
      location
      |> Location.changeset(attrs)
      |> put_hide_flag(scope, attrs)
      |> Location.validate_user_owned_type()
      |> Location.validate_common_ancestry()

    with {:ok, updated} <- Repo.update(changeset) do
      if updated.location_type != old_type do
        Location.Query.move_descendants(updated.id, old_type, updated.location_type)
      end

      {:ok, updated}
    end
  end

  @doc """
  Deletes a location.

  Refuses with `{:error, :forbidden}` when the scope may not modify it, or with
  `{:error, :has_children}` / `{:error, :has_checklists}` /
  `{:error, :has_ebird_link}` when it is still in use. The eBird guard keeps a
  delete from silently discarding a curated eBird region link (the FK would
  nilify it); unlink in the eBird workbench first.
  """
  def delete_location(scope, %Location{} = location) do
    children = children_count(location.id)
    checklists = checklists_count(location.id)

    cond do
      not can_manage?(scope, location) ->
        {:error, :forbidden}

      children > 0 ->
        {:error, :has_children}

      checklists > 0 ->
        {:error, :has_checklists}

      ebird_linked?(location) ->
        {:error, :has_ebird_link}

      true ->
        Repo.delete(location)
    end
  end

  defp ebird_linked?(location) do
    Kjogvi.Geo.EbirdLocation.Query.for_location(location.id)
    |> Repo.exists?()
  end
end
