defmodule Kjogvi.Search.Taxon do
  @moduledoc """
  Taxon search functionality with support for scientific and English names.
  Searches are scoped by user's default book.

  Results are ordered seen-first: every taxon the user has observed ranks above
  every taxon they have not. Within each group, results are ordered by text
  match quality and then by how often the user has observed the taxon.
  """

  import Ecto.Query

  alias Ornitho.Schema.Book
  alias Kjogvi.Search.WordMatch

  @limit 20

  @doc """
  Search for taxa by name (scientific or English).

  Taxa the user has observed are always ranked above taxa they have not.

  A taxon matches when every word of the query is a prefix of some word in its
  scientific or English name (words split on spaces, hyphens, apostrophes, and
  similar punctuation). Matching is anchored to word starts, so "great cr" finds
  Great Crested Grebe but not Great Reed Warbler / Acrocephalus.

  A taxon also matches when the whole query is a prefix of its primary `code` or
  of any code in its `codes` array, so "houspa" finds House Sparrow by its eBird
  code.

  Within the observed group, the most frequently observed come first. Within
  the unobserved group, results are ranked by text match quality:
  - Scientific name exact match (highest priority)
  - English name exact match
  - Code exact match
  - Scientific name starts with query
  - English name starts with query
  - A word in either name starts with the query
  - Code starts with query

  Names break any remaining ties alphabetically.

  Returns taxa with an additional `:key` field containing the full taxon signature
  (e.g., "/ebird/v2024/houspa") suitable for use as `taxon_key` in observations.

  ## Examples

      iex> search_taxa("grey shrike", user)
      [%{code: "...", key: "/ebird/v2024/grytit1", name_en: "Grey Shrike-tit", name_sci: "..."}, ...]

      iex> search_taxa("tit", user)
      [%{code: "...", key: "/ebird/v2024/gretit1", name_en: "Great Tit", name_sci: "..."}, ...]
  """
  def search_taxa(query_text, user) when is_binary(query_text) and byte_size(query_text) > 0 do
    query_text = String.downcase(String.trim(query_text))

    case get_user_book(user) do
      {:ok, book} ->
        counts = observation_counts(user)

        book
        |> all_taxa()
        |> Enum.filter(&matches_query?(&1, query_text))
        |> Enum.sort_by(&sort_priority(&1, query_text, counts, book))
        |> Enum.take(@limit)
        |> Enum.map(&add_taxon_key(&1, book))

      :error ->
        []
    end
  end

  def search_taxa(_, _), do: []

  @doc """
  Get all taxa from a book.
  """
  def all_taxa(book) do
    Ornitho.Finder.Taxon.all(book)
  end

  defp get_user_book(user) do
    if is_nil(user.default_book_signature) do
      :error
    else
      [slug, version] = String.split(user.default_book_signature, "/")

      case Ornitho.Finder.Book.by_signature(slug, version) do
        %Book{} = book -> {:ok, book}
        nil -> :error
      end
    end
  end

  defp matches_query?(taxon, query_text) do
    name_en_lower = String.downcase(taxon.name_en || "")
    name_sci_lower = String.downcase(taxon.name_sci || "")

    # Split the query on the same boundaries as names, so "yellow-rumped"
    # becomes ["yellow", "rumped"] and matches the hyphenated name word-for-word.
    query_words = WordMatch.split_words(query_text)

    # Every query word must be a prefix of some word in one of the names (AND
    # across query words). Word-prefix — not substring-anywhere — keeps results
    # precise: "great cr" finds Great Crested (cr- starts "crested") but not
    # Great Reed Warbler / Acrocephalus, where nothing begins with "cr".
    name_match =
      Enum.all?(query_words, fn word ->
        WordMatch.word_prefix_match?(name_en_lower, word) ||
          WordMatch.word_prefix_match?(name_sci_lower, word)
      end)

    name_match || code_prefix_match?(taxon, query_text)
  end

  # A code is a single token with no spaces, so the whole trimmed query (not its
  # individual words) must be a prefix of `code` or of some entry in `codes`.
  defp code_prefix_match?(taxon, query_text) do
    has_code?(taxon, &String.starts_with?(&1, query_text))
  end

  defp observation_counts(user) do
    Kjogvi.Repo.all(
      from(o in Kjogvi.Birding.Observation,
        join: c in assoc(o, :checklist),
        where: c.user_id == ^user.id,
        group_by: o.taxon_key,
        select: {o.taxon_key, count(o.id)}
      )
    )
    |> Map.new()
  end

  # Sort key: `{seen_bucket, weight, match_tier, name}`.
  #
  # `seen_bucket` is the primary key: every taxon the user has observed (0)
  # ranks above every taxon they have not (1). Within the seen group, the most
  # frequently observed come first (`weight`); within the unseen group, where
  # `weight` is 0 for all, text-match quality (`match_tier`) orders results.
  # `name` breaks remaining ties alphabetically.
  defp sort_priority(taxon, query_text, counts, book) do
    name_en = String.downcase(taxon.name_en || "")
    name_sci = String.downcase(taxon.name_sci || "")
    count = observation_count(taxon, counts, book)
    seen_bucket = if count > 0, do: 0, else: 1
    weight = -count

    {tier, name} =
      match_exact(name_sci, name_en, query_text) ||
        match_code_exact(taxon, query_text, name_en) ||
        match_starts_with(name_sci, name_en, query_text) ||
        match_word_start(name_sci, name_en, query_text) ||
        match_code_prefix(taxon, query_text, name_en) ||
        {8, name_en}

    {seen_bucket, weight, tier, name}
  end

  defp observation_count(taxon, counts, book) do
    key = "/#{book.slug}/#{book.version}/#{taxon.code}"
    Map.get(counts, key, 0)
  end

  defp match_exact(name_sci, name_en, query) do
    cond do
      name_sci == query -> {0, ""}
      name_en == query -> {1, ""}
      true -> nil
    end
  end

  defp match_code_exact(taxon, query, name_en) do
    if has_code?(taxon, &(&1 == query)), do: {2, name_en}
  end

  defp match_starts_with(name_sci, name_en, query) do
    cond do
      String.starts_with?(name_sci, query) -> {3, name_sci}
      String.starts_with?(name_en, query) -> {4, name_en}
      true -> nil
    end
  end

  defp match_word_start(name_sci, name_en, query) do
    cond do
      WordMatch.word_prefix_match?(name_sci, query) -> {5, name_sci}
      WordMatch.word_prefix_match?(name_en, query) -> {6, name_en}
      true -> nil
    end
  end

  defp match_code_prefix(taxon, query, name_en) do
    if has_code?(taxon, &String.starts_with?(&1, query)), do: {7, name_en}
  end

  defp has_code?(taxon, fun) do
    [taxon.code | taxon.codes || []]
    |> Enum.any?(fn code -> code && fun.(String.downcase(code)) end)
  end

  defp add_taxon_key(taxon, book) do
    Map.put(taxon, :key, "/#{book.slug}/#{book.version}/#{taxon.code}")
  end
end
