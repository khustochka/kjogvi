defmodule KjogviWeb.Paths.Lifelist do
  @moduledoc """
  Generating Lifelist paths.
  """

  use KjogviWeb, :verified_routes

  alias KjogviWeb.Paths

  @spec lifelist_path(integer() | nil, String.t() | %{slug: String.t()} | nil, Enum.t() | nil) ::
          String.t()
  def lifelist_path(year, location, query \\ nil) do
    lifelist_p(year, extract_location(location), Paths.clean_query(query))
  end

  def lifelist_path(opts) when is_map(opts) do
    {year, location, query_params} = split_params(opts)

    lifelist_p(year, location, query_params)
  end

  def lifelist_path(opts) do
    lifelist_path(Enum.into(opts, %{}))
  end

  defp extract_location(%{slug: slug}) do
    slug
  end

  defp extract_location(slug) when is_binary(slug) or is_nil(slug) do
    slug
  end

  def split_params(%{year: year, location: location, query: query}) do
    {year, extract_location(location), Paths.clean_query(query)}
  end

  def split_params(%{year: year, location: location}) do
    {year, extract_location(location), nil}
  end

  defp lifelist_p(nil = _year, nil = _location, query) do
    ~p"/lifelist?#{query}"
  end

  defp lifelist_p(year, nil = _location, query) do
    ~p"/lifelist/#{year}?#{query}"
  end

  defp lifelist_p(nil = _year, location_slug, query) do
    ~p"/lifelist/#{location_slug}?#{query}"
  end

  defp lifelist_p(year, location_slug, query) do
    ~p"/lifelist/#{year}/#{location_slug}?#{query}"
  end
end