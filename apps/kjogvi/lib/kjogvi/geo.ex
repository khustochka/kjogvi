defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

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
          Enum.filter(all, fn child ->
            effective_lifelist_parent(child.ancestry, lifelist_ids) == loc.id
          end)

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
      |> where([l], l.location_type in ["country", "region"] or is_nil(l.cached_country_id))
      |> select(fragment("distinct unnest(array_append(ancestry, id))"))

    # Need to add null type, because it is not matching != "special"
    from(l in Location,
      where:
        l.id in subquery(good_children_ids) and
          (l.location_type != "special" or is_nil(l.location_type))
    )
    |> Repo.all()
  end

  @doc """
  Returns all non-special locations grouped by parent ID (last element of ancestry).

  Top-level locations (no parent) are grouped under `nil`.
  """
  def all_locations_by_parent do
    from(l in Location,
      where: l.location_type != "special" or is_nil(l.location_type)
    )
    |> Repo.all()
    |> Enum.group_by(&List.last(&1.ancestry))
  end

  def get_child_locations(parent_id) do
    Location
    |> Location.Query.load_cards_count()
    |> where([l], fragment("? @> ?::bigint[]", l.ancestry, [^parent_id]))
    |> where([l], l.location_type != "special" or is_nil(l.location_type))
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
  def special_member_locations(%Location{location_type: "special"} = location) do
    location
    |> Repo.preload(special_child_locations: from(l in Location, order_by: l.name_en))
    |> Map.get(:special_child_locations)
  end

  def special_member_locations(%Location{}), do: []

  def get_specials do
    Location
    |> Location.Query.specials()
    |> Repo.all()
  end

  def location_by_slug(slug) do
    Location
    |> Location.Query.by_slug(slug)
    |> Repo.one()
  end

  def location_by_slug_scope(scope, slug) do
    if is_nil(scope.user) or not scope.private_view do
      Location |> Location.Query.only_public()
    else
      Location
    end
    |> Location.Query.by_slug(slug)
    |> Repo.one()
  end

  def search_locations(term, opts \\ []) do
    Location
    |> Location.Query.search(term, opts)
    |> Repo.all()
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
end
