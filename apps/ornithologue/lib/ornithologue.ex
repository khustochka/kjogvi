defmodule Ornithologue do
  @moduledoc """
  Documentation for `Ornithologue`.
  """

  import Ecto.Query

  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @spec get_taxa_and_species([String.t()]) :: %{String.t() => Ornitho.Schema.Taxon.t() | nil}

  # This is not required, but helps avoid unnecessary SQL query
  def get_taxa_and_species([]) do
    %{}
  end

  def get_taxa_and_species(key_list) do
    by_book = extract_books_and_codes(key_list)

    # No books is a starting point
    books =
      Enum.reduce(Map.keys(by_book), where(Book, fragment("1 = 0")), fn {slug, version}, query ->
        query |> or_where(slug: ^slug, version: ^version)
      end)
      |> repo().all()

    books
    |> Enum.reduce(%{}, fn book, acc ->
      grouped =
        Ornitho.Finder.Taxon.by_codes(book, by_book[{book.slug, book.version}])
        |> repo().preload(:parent_species)
        |> Enum.group_by(&Taxon.key(%{&1 | book: book}))
        |> Enum.map(fn {key, [val | _]} -> {key, val} end)
        |> Enum.into(%{})

      acc
      |> Map.merge(grouped)
    end)
  end

  @spec extract_books_and_codes([String.t()]) :: %{{String.t(), String.t()} => [String.t()]}
  defp extract_books_and_codes(key_list) do
    key_list
    |> Enum.reduce(%{}, fn key, acc ->
      ["", book_slug, book_version, taxon_code] = String.split(key, "/")

      book_sig = {book_slug, book_version}
      list = acc[book_sig] || []

      Map.put(acc, book_sig, [taxon_code | list])
    end)
  end

  def repo() do
    Application.fetch_env!(:ornithologue, :repo)
  end
end
