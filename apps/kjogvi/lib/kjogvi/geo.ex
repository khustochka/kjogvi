defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

  alias Kjogvi.Accounts.User
  alias Kjogvi.Repo
  alias __MODULE__.EbirdLocation
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
  A map of `location_type => %{total: n, matched: n}` over the eBird locations
  dataset, where matched rows are those linked to a common location.
  """
  def ebird_location_counts_by_type do
    EbirdLocation.Query.count_by_type_with_matched()
    |> Repo.all()
    |> Map.new(fn {type, total, matched} -> {type, %{total: total, matched: matched}} end)
  end

  @doc """
  Match stats and derived status for every eBird country, keyed by country
  code. Each entry carries `:status` (see
  `Kjogvi.Geo.EbirdLocation.Query.derive_status/1`) plus the underlying
  counts: `country_linked`, `country_code_match`, `sub1_total`, `sub1_linked`,
  `sub1_code_matched`, `iso_sub1_total`, `iso_extra`.
  """
  def ebird_country_statuses do
    ebird_statuses_from(EbirdLocation)
  end

  @doc """
  The `ebird_country_statuses/0` entry for one country, or nil if the country
  code is unknown.
  """
  def ebird_country_status(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> ebird_statuses_from()
    |> Map.get(country_code)
  end

  defp ebird_statuses_from(base) do
    sub1 =
      base
      |> EbirdLocation.Query.sub1_match_stats()
      |> Repo.all()
      |> Map.new(&{&1.country_code, &1})

    iso =
      base
      |> EbirdLocation.Query.iso_sub1_stats()
      |> Repo.all()
      |> Map.new(&{&1.country_code, &1})

    base
    |> EbirdLocation.Query.country_match_stats()
    |> Repo.all()
    |> Map.new(fn country ->
      stats =
        country
        |> Map.merge(
          Map.get(sub1, country.country_code, %{
            sub1_total: 0,
            sub1_linked: 0,
            sub1_code_matched: 0
          })
        )
        |> Map.merge(Map.get(iso, country.country_code, %{iso_sub1_total: 0, iso_extra: 0}))

      {country.country_code, Map.put(stats, :status, EbirdLocation.Query.derive_status(stats))}
    end)
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
  Returns scoped non-special locations as a flat list ordered by name, each with
  its `checklists_count` loaded and level FK associations preloaded for display names.

  Restricted to the locations `scope` may see (own + common).
  """
  def list_locations(scope) do
    scoped_locations(scope)
    |> where([l], l.location_type != :special or is_nil(l.location_type))
    |> order_by([l], asc: l.name_en)
    |> Location.Query.load_checklists_count()
    |> Repo.all()
    |> Location.Query.put_levels()
  end

  @doc """
  Builds the full location tree for `scope`'s locations index.

  Every location is placed under its direct parent — the deepest ancestor named
  by its level FKs (`Location.parent_id_from_levels/1`) — so the tree follows the
  real hierarchy to any depth, with skipped levels handled (a site with no city
  hangs off its subdivision). The common `country` / `subdivision1` scaffold is
  included only where the user has locations under it; the untouched shared
  scaffold is omitted. Specials are excluded (they render separately). Each level
  is ordered by name.

  Returns a list of uniform nodes, recursively:

      [%{location: %Location{}, children: [%{location: ..., children: [...]}]}]

  A node's `children` are the locations whose direct parent is that node; a leaf
  has an empty `children` list.
  """
  def location_tree(scope) do
    list_locations(scope)
    |> reject_orphan_common()
    |> build_tree()
  end

  @doc """
  Builds the tree of the entire common (unowned) scaffold, specials excluded —
  every country and subdivision regardless of whether anything hangs under it.

  Same node shape as `location_tree/1`; used by the admin common-locations index.
  """
  def common_location_tree do
    Location
    |> Location.Query.only_common()
    |> Location.Query.exclude_specials()
    |> Repo.all()
    |> build_tree()
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

  # `list_locations` returns the user's own locations plus the *entire* common
  # scaffold (every country and subdivision). Keep only common locations that are
  # an ancestor of some personal location, so the untouched scaffold is dropped.
  defp reject_orphan_common(locations) do
    needed_common_ids =
      locations
      |> Enum.reject(&is_nil(&1.user_id))
      |> Enum.flat_map(&Location.ancestor_ids/1)
      |> MapSet.new()

    Enum.filter(locations, fn loc ->
      not is_nil(loc.user_id) or MapSet.member?(needed_common_ids, loc.id)
    end)
  end

  defp build_nodes(locations, by_parent) do
    locations
    |> Enum.sort_by(&{Map.get(@level_rank, &1.location_type, 99), &1.name_en})
    |> Enum.map(fn location ->
      children = Map.get(by_parent, location.id, [])
      %{location: location, children: build_nodes(children, by_parent)}
    end)
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
  Creates a location owned by the scope's `current_user`.
  """
  def create_location(scope, attrs) do
    %Location{}
    |> Location.changeset(attrs)
    |> Ecto.Changeset.put_change(:user_id, scope.current_user && scope.current_user.id)
    |> Location.validate_user_owned_type()
    |> Repo.insert()
  end

  @doc """
  Updates a location.

  When the `location_type` changes, the descendants' level FKs are cascaded in
  the same transaction so they keep pointing at this location through the column
  for its new level.

  Returns `{:error, :forbidden}` when the scope may not modify the location.
  Ownership (`user_id`) is not editable, so it is never changed here.
  """
  def update_location(scope, %Location{} = location, attrs) do
    if User.owns?(scope.current_user, location) do
      Repo.transact(fn -> update_and_cascade(location, attrs) end)
    else
      {:error, :forbidden}
    end
  end

  # Updates the location and, when its `location_type` changed, cascades the
  # descendants' level FKs onto the new level column. Runs inside the
  # `update_location/3` transaction.
  defp update_and_cascade(location, attrs) do
    old_type = location.location_type

    changeset =
      location
      |> Location.changeset(attrs)
      |> Location.validate_user_owned_type()

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
  `{:error, :has_children}` / `{:error, :has_checklists}` when it is still in use.
  """
  def delete_location(scope, %Location{} = location) do
    children = children_count(location.id)
    checklists = checklists_count(location.id)

    cond do
      not User.owns?(scope.current_user, location) ->
        {:error, :forbidden}

      children > 0 ->
        {:error, :has_children}

      checklists > 0 ->
        {:error, :has_checklists}

      true ->
        Repo.delete(location)
    end
  end
end
