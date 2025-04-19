defmodule Ornithologue do
  @moduledoc """
  Documentation for `Ornithologue`.
  """

  import Ecto.Query

  alias Ornitho.Query
  alias Ornitho.Query.Utils
  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon

  @spec get_taxa_and_species([String.t()]) :: %{String.t() => Ornitho.Schema.Taxon.t() | nil}

  # This is not required, but helps avoid unnecessary SQL query
  def get_taxa_and_species([]) do
    %{}
  end

  def get_taxa_and_species(key_list) do
    by_book = extract_books_and_codes(key_list)

    books =
      from(book in Book,
        where: ^Utils.tuple_in([:slug, :version], Map.keys(by_book))
      )
      |> Query.Book.select_signature()
      |> repo().all()

    books
    |> Enum.reduce(%{}, fn book, acc ->
      grouped =
        Query.Taxon.by_book(book)
        |> Query.Taxon.select_minimal()
        |> Query.Taxon.by_codes(by_book[{book.slug, book.version}])
        |> repo().all()
        |> repo().preload(:parent_species)
        |> Enum.map(fn taxon ->
          add_book_to_taxon_and_species(taxon, book)
        end)
        |> Enum.group_by(&Taxon.key/1)
        |> Enum.map(fn {key, [val | _]} -> {key, val} end)
        |> Map.new()

      acc
      |> Map.merge(grouped)
    end)
  end

  defp add_book_to_taxon_and_species(taxon, book) do
    new_taxon =
      case taxon.parent_species do
        nil -> taxon
        species -> Map.put(taxon, :parent_species, %{species | book: book})
      end

    Map.put(new_taxon, :book, book)
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
