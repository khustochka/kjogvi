defmodule KjogviWeb.Paths.LifelistPath do
  @moduledoc """
  Generating Lifelist paths.
  """

  use KjogviWeb, :verified_routes

  alias KjogviWeb.Paths
  alias Kjogvi.Birding.Lifelist

  def lifelist_path(path_opts \\ [], query \\ nil, privacy_opts \\ [])

  def lifelist_path(%Lifelist.Filter{} = filter, query, privacy_opts) do
    {year, location, query_params} = split_params(filter, query)

    lifelist_gen_path(year, location, query_params, privacy_opts)
  end

  def lifelist_path(path_opts, query, privacy_opts) when is_map(path_opts) do
    path_opts
    |> Map.to_list()
    |> lifelist_path(query, privacy_opts)
  end

  def lifelist_path(path_opts, query, privacy_opts) do
    lifelist_path(Lifelist.Filter.discombo!(path_opts), query, privacy_opts)
  end

  def split_params(filter, query) do
    {%{year: year, location: location}, query_filters} =
      filter
      |> Map.from_struct()
      |> Map.split([:year, :location])

    query_filters
    |> Map.merge(Map.new(query || []))
    |> Paths.clean_query()
    |> then(&{year, location, Paths.clean_query(&1)})
  end

  def split_params(%{year: year, location: location}) do
    {year, location, nil}
  end

  defp lifelist_gen_path(year, location, query, private_view: true) do
    my_lifelist_p(year, location, query)
  end

  defp lifelist_gen_path(year, location, query, _) do
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
