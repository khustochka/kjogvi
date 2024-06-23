defmodule KjogviWeb.Paths.Lifelist do
  @moduledoc """
  Generating Lifelist paths.
  """

  use KjogviWeb, :verified_routes

  alias KjogviWeb.Paths

  def lifelist_path(opts, query \\ nil)

  def lifelist_path(filter, query) do
    {year, location, query_params} = split_params(filter, query)

    lifelist_p(year, location, query_params)
  end

  # def lifelist_path(opts, query) when is_map(opts) do
  #   {year, location, query_params} = split_params(opts, query)

  #   lifelist_p(year, location, query_params)
  # end

  # def lifelist_path(opts, query) do
  #   lifelist_path(Enum.into(opts, %{}), query)
  # end

  def split_params(filter, query) do
    {%{year: year, location: location}, query_filters} =
      filter
      |> Map.from_struct()
      |> Map.split([:year, :location])

    query_filters
    |> Map.merge(Enum.into(query, %{}))
    |> Paths.clean_query()
    |> then(fn query_params ->
      {year, location, Paths.clean_query(query_params)}
    end)
  end

  def split_params(%{year: year, location: location}) do
    {year, location, nil}
  end

  defp lifelist_p(nil = _year, nil = _location, query) do
    ~p"/lifelist?#{query}"
  end

  defp lifelist_p(year, nil = _location, query) do
    ~p"/lifelist/#{year}?#{query}"
  end

  defp lifelist_p(nil = _year, location, query) do
    ~p"/lifelist/#{location}?#{query}"
  end

  defp lifelist_p(year, location, query) do
    ~p"/lifelist/#{year}/#{location}?#{query}"
  end
end
