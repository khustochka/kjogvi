defmodule KjogviWeb.Paths.LifelistPath do
  @moduledoc """
  Generating Lifelist paths.
  """

  use KjogviWeb, :verified_routes

  alias KjogviWeb.Paths
  alias Kjogvi.Birding.Lifelist

  @filter_exclude_from_query []

  def lifelist_path(scope, path_opts \\ [])

  def lifelist_path(scope, %Lifelist.Filter{} = filter) do
    {year, location, query_params} = split_params(filter)

    lifelist_gen_path(scope, year, location, query_params)
  end

  def lifelist_path(scope, path_opts) when is_map(path_opts) do
    path_opts
    |> Map.to_list()
    |> lifelist_path(scope)
  end

  def lifelist_path(scope, path_opts) do
    lifelist_path(scope, Lifelist.Filter.discombo!(path_opts))
  end

  def split_params(filter) do
    {%{year: year, location: location}, query_filters} =
      filter
      |> Map.from_struct()
      |> Map.split([:year, :location])

    query_filters
    |> Map.drop(@filter_exclude_from_query)
    |> Paths.clean_query()
    |> then(&{year, location, &1})
  end

  defp lifelist_gen_path(%{private_view: true} = _scope, year, location, query) do
    my_lifelist_p(year, location, query)
  end

  defp lifelist_gen_path(_scope, year, location, query) do
    lifelist_p(year, location, query)
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

  defp my_lifelist_p(nil = _year, nil = _location, query) do
    ~p"/my/lifelist?#{query}"
  end

  defp my_lifelist_p(year, nil = _location, query) do
    ~p"/my/lifelist/#{year}?#{query}"
  end

  defp my_lifelist_p(nil = _year, location, query) do
    ~p"/my/lifelist/#{location}?#{query}"
  end

  defp my_lifelist_p(year, location, query) do
    ~p"/my/lifelist/#{year}/#{location}?#{query}"
  end
end
