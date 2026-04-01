defmodule Kjogvi.Birding.Lifelist do
  @moduledoc """
  Lifelist generation.
  """

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  alias Kjogvi.Birding.LifeObservation
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
  def generate(scope, filter \\ [])

  def generate(scope, %Filter{} = filter) do
    generate_with_species(scope, filter)
    |> Location.Query.preload_all_locations()
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

  def generate(scope, filter) do
    filter |> Filter.discombo!() |> then(&generate(scope, &1))
  end

  @spec top(scope(), integer()) :: Result.t()
  @spec top(scope(), integer(), filter()) :: Result.t()
  @doc """
  Get N newest species on the list based on provided filter options.
  """
  def top(scope, n, filter \\ [])

  def top(scope, n, %Filter{} = filter) when is_integer(n) and n > 0 do
    list = generate_with_species(scope, filter)
    total_species = length(list)

    %Result{
      user: scope.user,
      include_private: scope.include_private,
      filter: filter,
      list: Enum.take(list, n),
      total: total_species
    }
  end

  def top(scope, n, filter) do
    filter |> Filter.discombo!() |> then(&top(scope, n, &1))
  end

  @spec years(scope()) :: list(integer())
  @spec years(scope(), filter()) :: list(integer())
  @doc """
  Get all years in a list based on provided filter options.
  """
  def years(scope, filter \\ []) do
    Lifelist.Query.years_query(scope, filter)
    |> Repo.all()
    |> Enum.sort()
  end

  @spec months(scope()) :: list(integer())
  @spec months(scope(), filter()) :: list(integer())
  @doc """
  Get all months in a list based on provided filter options.
  """
  def months(scope, filter \\ []) do
    Lifelist.Query.months_query(scope, filter)
    |> Repo.all()
    |> Enum.sort()
  end

  @spec location_ids(scope()) :: list(integer())
  @spec location_ids(scope(), filter()) :: list(integer())
  @doc """
  Get IDs of lifelist locations (those with `public_index` set) that have
  observations matching the given filter.
  """
  def location_ids(scope, filter \\ []) do
    Lifelist.Query.location_ids_query(scope, filter)
    |> Repo.all()
  end

  # ===

  defp generate_with_species(scope, filter, opts \\ []) do
    Lifelist.Query.lifelist_query(scope, filter, opts)
    |> fetch_with_species()
  end

  defp fetch_with_species(query) do
    query
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(:species_page)
  end

  defp maybe_add_extras(scope, %{filter: filter = %{exclude_heard_only: true}} = result) do
    seen_species_page_ids = Enum.map(result.list, & &1.species_page_id)

    heard_only_list =
      Lifelist.Query.lifelist_query(scope, %{filter | exclude_heard_only: false},
        excluding_species: seen_species_page_ids
      )
      |> fetch_with_species()
      |> Location.Query.preload_all_locations()
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
