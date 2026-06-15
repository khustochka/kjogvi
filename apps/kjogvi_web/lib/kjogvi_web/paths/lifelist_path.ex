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
    lifelist_path(scope, Map.to_list(path_opts))
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
    |> Map.update(:sort, nil, fn
      :taxonomy -> "taxonomy"
      _ -> nil
    end)
    |> Paths.clean_query()
    |> then(&{year, location, &1})
  end

  # Routes the lifelist link to the section's own URL space. The private
  # (`:private`/`:admin`) lifelist lives under /my; a specific user's public
  # lifelist under /users/:username; the community lifelist under /lifelist.
  defp lifelist_gen_path(%{section: section} = _scope, year, location, query)
       when section in [:private, :admin] do
    my_lifelist_p(year, location, query)
  end

  defp lifelist_gen_path(
         %{section: :user, subject_user: %{nickname: nickname}},
         year,
         location,
         query
       ) do
    user_lifelist_p(nickname, year, location, query)
  end

  defp lifelist_gen_path(%{section: :community} = _scope, year, location, query) do
    community_lifelist_p(year, location, query)
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

  defp user_lifelist_p(nickname, nil = _year, nil = _location, query) do
    ~p"/users/#{nickname}/lifelist?#{query}"
  end

  defp user_lifelist_p(nickname, year, nil = _location, query) do
    ~p"/users/#{nickname}/lifelist/#{year}?#{query}"
  end

  defp user_lifelist_p(nickname, nil = _year, location, query) do
    ~p"/users/#{nickname}/lifelist/#{location}?#{query}"
  end

  defp user_lifelist_p(nickname, year, location, query) do
    ~p"/users/#{nickname}/lifelist/#{year}/#{location}?#{query}"
  end

  defp community_lifelist_p(nil = _year, nil = _location, query) do
    ~p"/community/lifelist?#{query}"
  end

  defp community_lifelist_p(year, nil = _location, query) do
    ~p"/community/lifelist/#{year}?#{query}"
  end

  defp community_lifelist_p(nil = _year, location, query) do
    ~p"/community/lifelist/#{location}?#{query}"
  end

  defp community_lifelist_p(year, location, query) do
    ~p"/community/lifelist/#{year}/#{location}?#{query}"
  end
end
