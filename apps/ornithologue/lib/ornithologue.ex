defmodule Ornithologue do
  @moduledoc """
  Documentation for `Ornithologue`.
  """

  import Ecto.Query

  alias Ornitho.Repo
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  def get_taxa_and_species(keys_list) do
    by_book =
      keys_list
      |> Enum.reduce(%{}, fn key, acc ->
        ["", book_slug, book_version, taxon_code] = String.split(key, "/")

        book_sig = {book_slug, book_version}
        list = acc[book_sig] || []

        Map.put(acc, book_sig, [taxon_code | list])
      end)

    book_query =
      Enum.reduce(Map.keys(by_book), Book, fn {slug, version}, query ->
        query
        |> or_where(slug: ^slug, version: ^version)
      end)

    books = book_query |> Repo.all()

    books
    |> Enum.reduce(%{}, fn book, acc ->
      grouped =
        Ornitho.Finder.Taxon.by_codes(book, by_book[{book.slug, book.version}])
        |> Enum.group_by(&Taxon.key(%{&1 | book: book}))
        |> Enum.map(fn {key, [val | _]} -> {key, val} end)
        |> Enum.into(%{})

      acc
      |> Map.merge(grouped)
    end)
  end
end
