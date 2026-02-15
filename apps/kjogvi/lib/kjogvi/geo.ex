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

  def get_all_locations_grouped do
    locations =
      Location
      |> Location.Query.load_cards_count()
      |> where([l], l.location_type != "special" or is_nil(l.location_type))
      |> Repo.all()

    # Group locations by their parent ID (last element of ancestry)
    grouped_locations =
      locations
      |> Enum.group_by(&List.last(&1.ancestry))

    {locations, grouped_locations}
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

  def children_count(location_id) do
    from(l in Location,
      where: fragment("? @> ?::bigint[]", l.ancestry, [^location_id]),
      select: count(l.id)
    )
    |> Repo.one()
  end
end
