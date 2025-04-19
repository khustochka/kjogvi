defmodule Kjogvi.Geo.Location.Query do
  @moduledoc """
  Queries for Locations.
  """

  @country_location_type "country"
  @special_location_type "special"

  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @minimal_select [
    :id,
    :slug,
    :name_en,
    :location_type,
    :is_private,
    :cached_parent_id,
    :cached_city_id,
    :cached_subdivision_id,
    :cached_country_id,
    :ancestry
  ]

  def minimal_select(query \\ Location) do
    from(query)
    |> select(^@minimal_select)
  end

  def by_slug(query, slug) do
    from l in query, where: l.slug == ^slug
  end

  def for_user(query, nil) do
    from l in query, where: l.is_private == false or is_nil(l.is_private)
  end

  def for_user(query, _user) do
    query
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

  def child_locations(%{id: id}) do
    from l in Location,
      where: fragment("? @> ?::bigint[]", l.ancestry, [^id]) or ^id == l.id
  end

  # Not sure they belong here.
  def preload_public_location(things) do
    things
    |> preload_location_ancestors
    |> Enum.map(fn thing ->
      put_in(thing.public_location, Location.public_location(thing.location))
    end)
  end

  def preload_all_locations(things) do
    things
    |> Repo.preload(
      location:
        {minimal_select(),
         [
           cached_parent: minimal_select(),
           cached_city: minimal_select(),
           cached_subdivision: minimal_select(),
           cached_country: minimal_select()
         ]}
    )
    |> preload_public_location()
  end

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

    # TODO: Preload ancestors for those that are private too

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
