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
  alias __MODULE__.Opts

  @doc """
  Generate lifelist based on provided filter options.
  """
  def generate(opts \\ %Opts{})

  def generate(%Opts{} = opts) do
    lifelist_query(opts)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(location: [:cached_parent, :cached_city, :cached_subdivision, :country])
    |> preload_public_location()
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
  end

  def generate(opts) do
    opts |> Opts.discombo() |> generate()
  end

  @doc """
  Get N newest species on the list based on provided filter options.
  """
  def top(n, opts \\ %Opts{})

  def top(n, %Opts{} = opts) when is_integer(n) and n > 0 do
    lifelist_query(opts)
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

  def top(n, opts) when is_integer(n) and n > 0 do
    opts |> Opts.discombo() |> then(&top(n, &1))
  end

  @doc """
  Get all years in a list based on provided filter options.
  """
  def years(opts \\ %Opts{})

  def years(%Opts{} = opts) do
    observations_filtered(opts)
    |> distinct(true)
    |> select([..., c], extract_year(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  def years(opts) do
    opts |> Opts.discombo() |> years()
  end

  @doc """
  Get all country ids in a list based on provided filter options.
  """
  def country_ids(opts \\ %Opts{})

  def country_ids(%Opts{} = opts) do
    location_ids =
      observations_filtered(opts)
      |> distinct(true)
      |> select([_o, c], [c.location_id])

    from(c in Kjogvi.Geo.Location)
    |> Geo.Location.Query.countries()
    |> join(:inner, [c], l in Kjogvi.Geo.Location, on: c.id == l.country_id or c.id == l.id)
    |> where([_c, l], l.id in subquery(location_ids))
    |> select([c], c.id)
    |> Repo.all()
  end

  def country_ids(opts) do
    opts |> Opts.discombo() |> country_ids()
  end

  # ----------------

  def observations_filtered(%Opts{} = opts) do
    base = from([o, c] in observation_base())

    Map.from_struct(opts)
    |> Enum.reduce(base, fn filter, query ->
      case filter do
        {:year, year} when not is_nil(year) ->
          Card.Query.by_year(query, year)

        {:month, month} when not is_nil(month) ->
          Card.Query.by_month(query, month)

        {:location, location} when not is_nil(location) ->
          Card.Query.by_location_with_descendants(query, location)

        _ ->
          query
      end
    end)
  end

  defp lifelist_query(opts) do
    from l in subquery(lifers_query(opts)),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query(opts) do
    from [o, c] in observations_filtered(opts),
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
