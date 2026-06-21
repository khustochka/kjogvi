defmodule Kjogvi.Search.Location do
  @moduledoc """
  Location search with priority ordering.

  Matches against `name_en`, `slug`, and `iso_code` (case-insensitive contains).
  Results are sorted by:

  1. Exact match on `iso_code`, `name_en`, or `slug`
  2. `name_en` or `slug` starts with the term
  3. A word in `name_en` or `slug` starts with the term
  4. Term appears anywhere

  Returns full `Location` structs with the level FK associations preloaded so
  callers can derive display names (e.g. `Location.long_name/2`).
  """

  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo
  alias Kjogvi.Search.WordMatch

  @default_limit 20

  @doc """
  Searches `query` (a `Location` queryable) for `term`.

  The caller supplies the base query, which is how scoping is applied: pass a
  query already restricted to the locations the current scope may see (see
  `Kjogvi.Geo.search_locations/3`).
  """
  def search_locations(query, term, opts \\ [])

  def search_locations(query, term, opts) when is_binary(term) do
    case String.trim(term) do
      "" ->
        []

      trimmed ->
        do_search(query, trimmed, opts)
    end
  end

  def search_locations(_, _, _), do: []

  defp do_search(query, term, opts) do
    limit = Keyword.get(opts, :limit, @default_limit)
    ilike_term = "%#{term}%"
    term_lower = String.downcase(term)

    query
    |> where(
      [l],
      ilike(l.name_en, ^ilike_term) or
        ilike(l.slug, ^ilike_term) or
        ilike(l.iso_code, ^ilike_term)
    )
    |> Repo.all()
    |> Location.Query.put_levels()
    |> Enum.sort_by(&sort_priority(&1, term_lower))
    |> Enum.take(limit)
  end

  defp sort_priority(location, term) do
    name = location.name_en |> to_string() |> String.downcase()
    slug = location.slug |> to_string() |> String.downcase()
    iso = location.iso_code |> to_string() |> String.downcase()

    bucket =
      cond do
        iso == term or name == term or slug == term -> 0
        String.starts_with?(name, term) or String.starts_with?(slug, term) -> 1
        WordMatch.word_prefix_match?(name, term) or WordMatch.word_prefix_match?(slug, term) -> 2
        true -> 3
      end

    {bucket, name}
  end
end
