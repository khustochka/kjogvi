defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

  alias Kjogvi.Accounts.User
  alias Kjogvi.Repo
  alias __MODULE__.Location

  def get_countries do
    Location
    |> Location.Query.countries()
    |> Repo.all()
  end

  @doc """
  Returns locations with `public_index` set, ordered by `public_index`.
  These are locations shown as filter options on the lifelist.
  """
  def get_lifelist_locations do
    from(l in Location,
      where: not is_nil(l.public_index),
      order_by: l.public_index
    )
    |> Repo.all()
  end

  @doc """
  Returns the set of locations the logbook settings UI can offer as toggles:
  all countries, all regions, and any other lifelist filter location
  (e.g. continents or specials) that doesn't fall into those types.

  Ordering is left to the caller — the settings UI groups regions under
  their country, which is easier to express in Elixir than in SQL.
  """
  def get_logbook_settings_locations do
    from(l in Location,
      where:
        l.location_type in [:country, :subdivision1] or
          not is_nil(l.public_index)
    )
    |> Repo.all()
  end

  @doc """
  Returns hierarchical context for the lifelist location filter.

  Given a selected location (or nil for "World"), returns:
  - `ancestors` — lifelist locations in the selected location's ancestry chain
  - `siblings` — lifelist locations sharing the same ancestry as selected
  - `children` — lifelist locations whose nearest lifelist ancestor is the selected location (or a sibling, for World)
  """
  def get_lifelist_location_context(selected_location) do
    all = get_lifelist_locations()
    lifelist_ids = MapSet.new(all, & &1.id)

    case selected_location do
      nil ->
        my_parent = nil

        siblings =
          Enum.filter(all, &(effective_lifelist_parent(&1.ancestry, lifelist_ids) == my_parent))

        sibling_ids = MapSet.new(siblings, & &1.id)

        children =
          Enum.filter(all, fn loc ->
            effective_lifelist_parent(loc.ancestry, lifelist_ids) in sibling_ids
          end)

        %{ancestors: [], siblings: siblings, children: children}

      loc ->
        my_parent = effective_lifelist_parent(loc.ancestry, lifelist_ids)

        ancestors =
          all
          |> Enum.filter(&(&1.id in loc.ancestry))
          |> Enum.sort_by(fn a -> Enum.find_index(loc.ancestry, &(&1 == a.id)) end)

        siblings =
          Enum.filter(all, fn sib ->
            sib.id != loc.id &&
              effective_lifelist_parent(sib.ancestry, lifelist_ids) == my_parent
          end)

        children =
          if my_parent == nil do
            # Top-level location: show children of all top-level locations
            top_level_ids = MapSet.new(siblings, & &1.id) |> MapSet.put(loc.id)

            Enum.filter(all, fn child ->
              effective_lifelist_parent(child.ancestry, lifelist_ids) in top_level_ids
            end)
          else
            Enum.filter(all, fn child ->
              effective_lifelist_parent(child.ancestry, lifelist_ids) == loc.id
            end)
          end

        %{ancestors: ancestors, siblings: siblings, children: children}
    end
  end

  # Returns the nearest lifelist ancestor id — the last id in the ancestry
  # chain that is present in the lifelist set.
  defp effective_lifelist_parent(ancestry, lifelist_ids) do
    ancestry
    |> Enum.reverse()
    |> Enum.find(&MapSet.member?(lifelist_ids, &1))
  end

  # We want to build a tree of locations, but it should stop on regions
  # Some countries do not have regions, so it should stop on countries
  # Also should include top level locations (ones without parents), but not special (???)
  # => all that do not belong to a country
  def get_upper_level_locations do
    good_children_ids =
      from(Location)
      |> where([l], l.location_type in [:country, :subdivision1] or is_nil(l.cached_country_id))
      |> select(fragment("distinct unnest(array_append(ancestry, id))"))

    # Need to add null type, because it is not matching != "special"
    from(l in Location,
      where:
        l.id in subquery(good_children_ids) and
          (l.location_type != :special or is_nil(l.location_type))
    )
    |> Repo.all()
  end

  @doc """
  Returns scoped non-special locations grouped by parent ID (last element of ancestry).

  Top-level locations (no parent) are grouped under `nil`. The result is
  restricted to the locations `scope` may see (own + common).
  """
  def locations_by_parent(scope) do
    scoped_locations(scope)
    |> where([l], l.location_type != :special or is_nil(l.location_type))
    |> Location.Query.load_cards_count()
    |> Repo.all()
    |> Enum.group_by(&List.last(&1.ancestry))
  end

  def get_child_locations(parent_id) do
    parent = Repo.get!(Location, parent_id)

    Location.Query.child_locations(parent)
    |> where([l], l.id != ^parent_id)
    |> Location.Query.load_cards_count()
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
    |> Location.Query.load_cards_count()
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

  def get_specials(scope) do
    scoped_locations(scope)
    |> Location.Query.specials()
    |> Repo.all()
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

  @doc """
  Searches locations visible to `scope`, restricting the base query to what the
  scope may see before delegating to `Kjogvi.Search.Location`.
  """
  def search_locations(scope, term, opts \\ []) do
    scoped_locations(scope)
    |> Kjogvi.Search.Location.search_locations(term, opts)
  end

  # The base query of locations a scope may see.
  defp scoped_locations(%{area: :admin}), do: Location

  defp scoped_locations(%{area: :private, current_user: user}) do
    Location |> Location.Query.for_user(user)
  end

  defp scoped_locations(_scope) do
    Location |> Location.Query.only_public()
  end

  def cards_count(location_id) do
    from(c in Kjogvi.Birding.Card,
      where: c.location_id == ^location_id,
      select: count(c.id)
    )
    |> Repo.one()
  end

  @doc """
  Returns direct children of a location (where it is the last element of ancestry).
  """
  def direct_children(location_id) do
    from(l in Location,
      where: fragment("?[array_length(?, 1)] = ?", l.ancestry, l.ancestry, ^location_id),
      order_by: l.name_en
    )
    |> Repo.all()
  end

  def children_count(location_id) do
    from(l in Location,
      where: fragment("? @> ?::bigint[]", l.ancestry, [^location_id]),
      select: count(l.id)
    )
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
    |> Repo.insert()
  end

  @doc """
  Updates a location.

  Returns `{:error, :forbidden}` when the scope may not modify the location.
  Ownership (`user_id`) is not editable, so it is never changed here.
  """
  def update_location(scope, %Location{} = location, attrs) do
    if User.owns?(scope.current_user, location) do
      location
      |> Location.changeset(attrs)
      |> Repo.update()
    else
      {:error, :forbidden}
    end
  end

  @doc """
  Returns true if the location can be deleted (no children, no cards).
  """
  def can_delete_location?(%Location{} = location) do
    children_count(location.id) == 0 and cards_count(location.id) == 0
  end

  @doc """
  Deletes a location.

  Refuses with `{:error, :forbidden}` when the scope may not modify it, or with
  `{:error, :has_children}` / `{:error, :has_cards}` when it is still in use.
  """
  def delete_location(scope, %Location{} = location) do
    children = children_count(location.id)
    cards = cards_count(location.id)

    cond do
      not User.owns?(scope.current_user, location) ->
        {:error, :forbidden}

      children > 0 ->
        {:error, :has_children}

      cards > 0 ->
        {:error, :has_cards}

      true ->
        Repo.delete(location)
    end
  end
end
