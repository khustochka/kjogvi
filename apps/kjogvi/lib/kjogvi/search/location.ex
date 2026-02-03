defmodule Kjogvi.Search.Location do
  @moduledoc """
  Location search functionality with full name matching.
  Searches by word components with priority on word beginnings.
  Searches all locations including hidden ones by English name.
  """

  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @limit 10

  @doc """
  Search for locations by name.

  Searches all locations (including hidden) by their full English name (hierarchical).
  Results are prioritized by:
  1. Full match of English name
  2. Name starts with query
  3. Name starts with a word in the name
  4. Name contains query (words separated by space, dash, brackets, commas, quotes)

  ## Examples

      iex> search_locations("park")
      [%{id: 1, name: "Central Park, New York, USA"}, ...]

      iex> search_locations("Central")
      [%{id: 1, name: "Central Park, New York, USA"}, ...]
  """
  def search_locations(query_text) when is_binary(query_text) and byte_size(query_text) > 0 do
    query_text = String.downcase(String.trim(query_text))

    Location
    |> preload([:cached_parent, :cached_city, :cached_subdivision, :cached_country])
    |> Repo.all()
    |> Enum.filter(&matches_query?(&1, query_text))
    |> Enum.sort_by(&sort_priority(&1, query_text))
    |> Enum.take(@limit)
    |> Enum.map(fn loc ->
      %{id: loc.id, long_name: Location.long_name(loc)}
    end)
  end

  def search_locations(_), do: []

  defp matches_query?(location, query_text) do
    name_lower = String.downcase(Location.full_name(location) || "")

    String.contains?(name_lower, query_text)
  end

  defp sort_priority(location, query_text) do
    name_lower = String.downcase(Location.full_name(location) || "")

    cond do
      # Exact match has highest priority
      name_lower == query_text ->
        {0, ""}

      # Starts with query has second priority
      String.starts_with?(name_lower, query_text) ->
        {1, name_lower}

      # Word-start matches have third priority
      starts_with_word?(name_lower, query_text) ->
        {2, name_lower}

      # Contains anywhere has lowest priority
      true ->
        {3, name_lower}
    end
  end

  defp starts_with_word?(text, query) do
    words = String.split(text, ~r/[\s\-\[\]\(\),'"]+/)
    Enum.any?(words, &String.starts_with?(&1, query))
  end
end
