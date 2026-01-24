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

  ## Examples

      iex> search_taxa("grey shrike", user)
      [%{code: "...", name_en: "Grey Shrike-tit", name_sci: "..."}, ...]

      iex> search_taxa("tit", user)
      [%{code: "...", name_en: "Great Tit", name_sci: "..."}, ...]
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
    name_en_lower = String.downcase(taxon.name_en || "")
    name_sci_lower = String.downcase(taxon.name_sci || "")

    cond do
      # Exact match on scientific name has highest priority
      name_sci_lower == query_text ->
        {0, ""}

      # Exact match on English name
      name_en_lower == query_text ->
        {1, ""}

      # Starts with query on scientific name
      String.starts_with?(name_sci_lower, query_text) ->
        {2, name_sci_lower}

      # Starts with query on English name
      String.starts_with?(name_en_lower, query_text) ->
        {3, name_en_lower}

      # Word-start matches on scientific name
      starts_with_word?(name_sci_lower, query_text) ->
        {4, name_sci_lower}

      # Word-start matches on English name
      starts_with_word?(name_en_lower, query_text) ->
        {5, name_en_lower}

      # Contains anywhere in scientific name
      String.contains?(name_sci_lower, query_text) ->
        {6, name_sci_lower}

      # Contains anywhere in English name
      true ->
        {7, name_en_lower}
    end
  end

  defp starts_with_word?(text, query) do
    words = String.split(text, ~r/[\s\-]+/)
    Enum.any?(words, &String.starts_with?(&1, query))
  end
end
