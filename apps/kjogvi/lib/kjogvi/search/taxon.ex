defmodule Kjogvi.Search.Taxon do
  @moduledoc """
  Taxon search functionality with support for scientific and English names.
  Searches are scoped by user's default book.
  Searches by word components with priority on word beginnings.
  """

  import Ecto.Query

  alias Ornitho.Schema.Book

  @limit 10

  @doc """
  Search for taxa by name (scientific or English).

  Searches are scoped to user's default book and search taxa by:
  - Scientific name exact match (highest priority)
  - English name exact match
  - Scientific name starts with query
  - English name starts with query
  - Word-start matching in either name
  - Contains anywhere in either name

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
        book
        |> all_taxa()
        |> Enum.filter(&matches_query?(&1, query_text))
        |> Enum.sort_by(&sort_priority(&1, query_text))
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
    book
    |> Ornitho.Query.Taxon.by_book()
    |> Ornithologue.repo().all()
  end

  defp get_user_book(user) do
    if is_nil(user.default_book_signature) do
      :error
    else
      [slug, version] = String.split(user.default_book_signature, "/")

      case Ornithologue.repo().one(
             from(b in Book,
               where: b.slug == ^slug and b.version == ^version
             )
           ) do
        %Book{} = book -> {:ok, book}
        nil -> :error
      end
    end
  end

  defp matches_query?(taxon, query_text) do
    name_en_lower = String.downcase(taxon.name_en || "")
    name_sci_lower = String.downcase(taxon.name_sci || "")

    query_words = String.split(query_text)

    Enum.any?(query_words, fn word ->
      String.contains?(name_en_lower, word) || String.contains?(name_sci_lower, word)
    end)
  end

  defp sort_priority(taxon, query_text) do
    name_en = String.downcase(taxon.name_en || "")
    name_sci = String.downcase(taxon.name_sci || "")

    check_exact_match(name_sci, name_en, query_text) ||
      check_starts_with(name_sci, name_en, query_text) ||
      check_word_start(name_sci, name_en, query_text) ||
      check_contains(name_sci, name_en, query_text) ||
      {7, name_en}
  end

  defp check_exact_match(name_sci, name_en, query) do
    cond do
      name_sci == query -> {0, ""}
      name_en == query -> {1, ""}
      true -> nil
    end
  end

  defp check_starts_with(name_sci, name_en, query) do
    cond do
      String.starts_with?(name_sci, query) -> {2, name_sci}
      String.starts_with?(name_en, query) -> {3, name_en}
      true -> nil
    end
  end

  defp check_word_start(name_sci, name_en, query) do
    cond do
      starts_with_word?(name_sci, query) -> {4, name_sci}
      starts_with_word?(name_en, query) -> {5, name_en}
      true -> nil
    end
  end

  defp check_contains(name_sci, name_en, query) do
    cond do
      String.contains?(name_sci, query) -> {6, name_sci}
      String.contains?(name_en, query) -> {6, name_en}
      true -> nil
    end
  end

  defp starts_with_word?(text, query) do
    words = String.split(text, ~r/[\s\-]+/)
    Enum.any?(words, &String.starts_with?(&1, query))
  end

  defp add_taxon_key(taxon, book) do
    Map.put(taxon, :key, "/#{book.slug}/#{book.version}/#{taxon.code}")
  end
end
