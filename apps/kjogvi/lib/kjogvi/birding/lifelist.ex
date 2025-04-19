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

  @type scope() :: Lifelist.Scope.t()
  @type filter() :: %Filter{} | keyword()

  # === MAIN API ===

  @spec generate(scope()) :: Result.t()
  @spec generate(scope(), filter()) :: Result.t()
  @doc """
  Generate lifelist based on provided filter options.
  """
  def generate(scope, filter \\ []) do
    generate_with_species(scope, filter)
    |> Location.Query.preload_all_locations()
    |> Enum.reverse()
    |> then(fn list ->
      %Result{
        user: scope.user,
        include_private: scope.include_private,
        filter: filter,
        list: list,
        total: length(list)
      }
    end)
    |> then(&maybe_add_extras(scope, &1))
  end

  @spec top(scope(), integer()) :: Result.t()
  @spec top(scope(), integer(), filter()) :: Result.t()
  @doc """
  Get N newest species on the list based on provided filter options.
  """
  def top(scope, n, filter \\ []) when is_integer(n) and n > 0 do
    Lifelist.Query.lifelist_query(scope, filter)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
    |> Enum.reverse()
    |> then(fn list ->
      %Result{
        user: scope.user,
        include_private: scope.include_private,
        filter: filter,
        list: Enum.take(list, n),
        total: length(list)
      }
    end)
  end

  @spec years(scope()) :: list(integer())
  @spec years(scope(), filter()) :: list(integer())
  @doc """
  Get all years in a list based on provided filter options.
  """
  def years(scope, filter \\ []) do
    Lifelist.Query.observations_filtered(scope, filter)
    |> distinct(true)
    |> select([..., c], extract_year(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @spec months(scope()) :: list(integer())
  @spec months(scope(), filter()) :: list(integer())
  @doc """
  Get all months in a list based on provided filter options.
  """
  def months(scope, filter \\ []) do
    Lifelist.Query.observations_filtered(scope, filter)
    |> distinct(true)
    |> select([..., c], extract_month(c.observ_date))
    |> Repo.all()
    |> Enum.sort()
  end

  @spec country_ids(scope()) :: list(integer())
  @spec country_ids(scope(), filter()) :: list(integer())
  @doc """
  Get all country ids in a list based on provided filter options.
  """
  def country_ids(scope, filter \\ []) do
    location_ids =
      Lifelist.Query.observations_filtered(scope, filter)
      |> distinct(true)
      |> select([_o, c], [c.location_id])

    from(c in Kjogvi.Geo.Location)
    |> Geo.Location.Query.countries()
    |> join(:inner, [c], l in Kjogvi.Geo.Location,
      on: c.id == l.cached_country_id or c.id == l.id
    )
    |> where([_c, l], l.id in subquery(location_ids))
    |> select([c], c.id)
    |> Repo.all()
  end

  # ===

  defp generate_with_species(scope, filter) do
    Lifelist.Query.lifelist_query(scope, filter)
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Kjogvi.Birding.preload_taxa_and_species()
    |> Enum.filter(& &1.species)
    |> Enum.uniq_by(& &1.species.code)
  end

  defp maybe_add_extras(scope, %{filter: filter = %{exclude_heard_only: true}} = result) do
    sp_codes =
      result.list
      |> Enum.map(& &1.species.code)

    new_filter = %{filter | exclude_heard_only: false}

    full_list =
      generate_with_species(scope, new_filter)

    heard_only_list =
      full_list
      |> Enum.reject(fn life_obs ->
        life_obs.species.code in sp_codes
      end)
      |> Location.Query.preload_all_locations()
      |> Enum.reverse()
      |> then(fn list ->
        %Result{
          list: list,
          total: length(list)
        }
      end)

    %{result | extras: %{heard_only: heard_only_list}}
  end

  defp maybe_add_extras(_scope, list) do
    list
  end
end
