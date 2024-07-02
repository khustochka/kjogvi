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
  alias __MODULE__.Filter
  alias __MODULE__.Result

  @type user() :: %Kjogvi.Users.User{} | %{id: integer()}
  @type filter() :: %Filter{} | keyword()

  # === MAIN API ===

  @spec generate(user()) :: Result.t()
  @spec generate(user(), filter()) :: Result.t()
  @doc """
  Generate lifelist based on provided filter options.
  """
  def generate(user, filter \\ %Filter{}) do
    lifelist_query(user, filter)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(location: [:cached_parent, :cached_city, :cached_subdivision, :country])
    |> preload_public_location()
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
    |> then(fn list ->
      %Result{
        user: user,
        filter: filter,
        list: list,
        total: length(list)
      }
    end)
  end

  @spec top(user(), integer()) :: Result.t()
  @spec top(user(), integer(), filter()) :: Result.t()
  @doc """
  Get N newest species on the list based on provided filter options.
  """
  def top(user, n, filter \\ %Filter{}) when is_integer(n) and n > 0 do
    lifelist_query(user, filter)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
    |> then(fn list ->
      %Result{
        user: user,
        filter: filter,
        list: Enum.take(list, n),
        total: length(list)
      }
    end)
  end

  @doc """
  Get all years in a list based on provided filter options.
  """
  def years(user, filter \\ %Filter{}) do
    observations_filtered(user, filter)
    |> distinct(true)
    |> select([..., c], extract_year(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @doc """
  Get all months in a list based on provided filter options.
  """
  def months(user, filter \\ %Filter{}) do
    observations_filtered(user, filter)
    |> distinct(true)
    |> select([..., c], extract_month(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @doc """
  Get all country ids in a list based on provided filter options.
  """
  def country_ids(user, filter \\ %Filter{}) do
    location_ids =
      observations_filtered(user, filter)
      |> distinct(true)
      |> select([_o, c], [c.location_id])

    from(c in Kjogvi.Geo.Location)
    |> Geo.Location.Query.countries()
    |> join(:inner, [c], l in Kjogvi.Geo.Location, on: c.id == l.country_id or c.id == l.id)
    |> where([_c, l], l.id in subquery(location_ids))
    |> select([c], c.id)
    |> Repo.all()
  end

  # ===

  @doc """
  Main entrypoint that converts filter into a query that returns observation matching it.
  """
  def observations_filtered(user, filter \\ %Filter{})

  def observations_filtered(user, %Filter{} = filter) do
    base = from([o, c] in observation_base(user))

    Map.from_struct(filter)
    |> Enum.reduce(base, fn filter, query ->
      case filter do
        {:year, year} when not is_nil(year) ->
          Card.Query.by_year(query, year)

        {:month, month} when not is_nil(month) ->
          Card.Query.by_month(query, month)

        {:location, location} when not is_nil(location) ->
          Card.Query.by_location_with_descendants(query, location)

        {:motorless, motorless} when motorless == true ->
          Card.Query.motorless(query)

        {:exclude_heard_only, exclude_heard_only} when exclude_heard_only == true ->
          # FIXME: move to Observation.Query ?
          query
          |> where([observation: o], o.voice == false)

        _ ->
          query
      end
    end)
  end

  def observations_filtered(user, filter) do
    filter |> Filter.discombo!() |> then(&observations_filtered(user, &1))
  end

  # ----------------

  defp lifelist_query(user, filter) do
    from l in subquery(lifers_query(user, filter)),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query(user, filter) do
    from [o, c] in observations_filtered(user, filter),
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

  defp observation_base(%{id: id} = _user) do
    from o in Observation,
      as: :observation,
      join: c in assoc(o, :card),
      as: :card,
      where: o.unreported == false and c.user_id == ^id
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
