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

  defp lifelist_gen_path(scope, year, location, query) do
    if scope.private_view do
      lifelist_p(:my, year, location, query)
    else
      lifelist_p(:public, year, location, query)
    end
  end

  defp lifelist_p(publicity, nil = _year, nil = _location, query) do
    case publicity do
      :public -> ~p"/lifelist?#{query}"
      :my -> ~p"/my/lifelist?#{query}"
    end
  end

  defp lifelist_p(publicity, year, nil = _location, query) do
    case publicity do
      :public -> ~p"/lifelist/#{year}?#{query}"
      :my -> ~p"/my/lifelist/#{year}?#{query}"
    end
  end

  defp lifelist_p(publicity, nil = _year, location, query) do
    case publicity do
      :public -> ~p"/lifelist/#{location}?#{query}"
      :my -> ~p"/my/lifelist/#{location}?#{query}"
    end
  end

  defp lifelist_p(publicity, year, location, query) do
    case publicity do
      :public -> ~p"/lifelist/#{year}/#{location}?#{query}"
      :my -> ~p"/my/lifelist/#{year}/#{location}?#{query}"
    end
  end
end
