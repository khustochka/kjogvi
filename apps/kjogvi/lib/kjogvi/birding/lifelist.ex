defmodule Kjogvi.Birding.Lifelist do
  @moduledoc """
  Lifelist generation.
  """

  import Ecto.Query
  import Kjogvi.Query.API

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Geo

  def generate(params \\ %{}) do
    lifelist_query(params)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(location: [:cached_parent, :cached_city, :cached_subdivision, :country])
    |> preload_public_location()
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
  end

  def top(n, params \\ %{}) when is_integer(n) and n > 0 do
    lifelist_query(params)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
    |> then(fn lifelist ->
      %{lifelist: Enum.take(lifelist, n), total: length(lifelist)}
    end)
  end

  def years(params \\ %{}) do
    observations_filtered(params)
    |> distinct(true)
    |> select([..., c], extract_year(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  def country_ids(params \\ %{}) do
    location_ids =
      observations_filtered(params)
      |> distinct(true)
      |> select([_o, c], [c.location_id])

    from(c in Kjogvi.Geo.Location)
    |> Geo.Location.Query.countries()
    |> join(:inner, [c], l in Kjogvi.Geo.Location, on: c.id == l.country_id or c.id == l.id)
    |> where([_c, l], l.id in subquery(location_ids))
    |> select([c], c.id)
    |> Repo.all()
  end

  def observations_filtered(params) do
    base = from([o, c] in observation_base())

    Enum.reduce(params, base, fn filter, query ->
      case filter do
        {:year, year} when not is_nil(year) ->
          Card.Query.by_year(query, year)

        {:location, location} when not is_nil(location) ->
          Card.Query.by_location_with_descendants(query, location)

        _ ->
          query
      end
    end)
  end

  defp lifelist_query(params) do
    from l in subquery(lifers_query(params)),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query(params) do
    from [o, c] in observations_filtered(params),
      distinct: o.taxon_key,
      order_by: [asc: o.taxon_key, asc: c.observ_date, asc_nulls_last: c.start_time, asc: o.id],
      select: %{
        id: o.id,
        card_id: c.id,
        taxon_key: o.taxon_key,
        observ_date: c.observ_date,
        start_time: c.start_time,
        location_id: c.location_id
      }
  end

  defp observation_base do
    from o in Observation,
      join: c in assoc(o, :card),
      where: o.unreported == false
  end

  # TODO: extract this to be usable universally
  def preload_public_location(things) do
    things
    |> preload_location_ancestors
    |> Enum.map(fn thing ->
      put_in(thing.public_location, Location.public_location(thing.location))
    end)
  end

  defp preload_location_ancestors(things) do
    # Only preload ancestors for private locations
    ancestor_loc_ids =
      things
      |> Enum.filter(fn lifer -> lifer.location.is_private end)
      |> Enum.flat_map(& &1.location.ancestry)
      |> Enum.uniq()

    loci =
      from(l in Location,
        where: l.id in ^ancestor_loc_ids,
        preload: [:cached_parent, :cached_city, :cached_subdivision, :country]
      )
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
