defmodule Kjogvi.Birding.Lifelist do
  @moduledoc """
  Lifelist generation.
  """

  import Ecto.Query
  import Kjogvi.Query.API

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Geo
  alias __MODULE__
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
  def generate(user, filter \\ []) do
    generate_with_species(user, filter)
    |> preload_all_location()
    |> Enum.reverse()
    |> then(fn list ->
      %Result{
        user: user,
        filter: filter,
        list: list,
        total: length(list)
      }
    end)
    |> maybe_add_extras()
  end

  @spec top(user(), integer()) :: Result.t()
  @spec top(user(), integer(), filter()) :: Result.t()
  @doc """
  Get N newest species on the list based on provided filter options.
  """
  def top(user, n, filter \\ []) when is_integer(n) and n > 0 do
    Lifelist.Query.lifelist_query(user, filter)
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
  def years(user, filter \\ []) do
    Lifelist.Query.observations_filtered(user, filter)
    |> distinct(true)
    |> select([..., c], extract_year(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @doc """
  Get all months in a list based on provided filter options.
  """
  def months(user, filter \\ []) do
    Lifelist.Query.observations_filtered(user, filter)
    |> distinct(true)
    |> select([..., c], extract_month(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @doc """
  Get all country ids in a list based on provided filter options.
  """
  def country_ids(user, filter \\ []) do
    location_ids =
      Lifelist.Query.observations_filtered(user, filter)
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

  defp generate_with_species(user, filter) do
    Lifelist.Query.lifelist_query(user, filter)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
  end

  defp maybe_add_extras(result = %{filter: filter = %{exclude_heard_only: true}, user: user}) do
    sp_codes =
      result.list
      |> Enum.map(& &1.species.code)

    new_filter = %{filter | exclude_heard_only: false}

    full_list =
      generate_with_species(user, new_filter)

    heard_only_list =
      full_list
      |> Enum.reject(fn life_obs ->
        life_obs.species.code in sp_codes
      end)
      |> preload_all_location()
      |> Enum.reverse()
      |> then(fn list ->
        %Result{
          list: list,
          total: length(list)
        }
      end)

    %{result | extras: %{heard_only: heard_only_list}}
  end

  defp maybe_add_extras(list) do
    list
  end

  # TODO: extract this to be usable universally
  defp preload_public_location(things) do
    things
    |> preload_location_ancestors
    |> Enum.map(fn thing ->
      put_in(thing.public_location, Location.public_location(thing.location))
    end)
  end

  defp preload_all_location(things) do
    things
    |> Repo.preload(location: [:cached_parent, :cached_city, :cached_subdivision, :country])
    |> preload_public_location()
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
