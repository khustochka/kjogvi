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

  def get_taxa_and_species(key_list, opts \\ [])

  # This is not required, but helps avoid unnecessary SQL query
  def get_taxa_and_species([], _opts) do
    %{}
  end

  def get_taxa_and_species(key_list, opts) do
    case extract_books_and_codes(key_list) do
      by_book when map_size(by_book) == 0 -> %{}
      by_book -> fetch_taxa_by_book(by_book, opts)
    end
  end

  defp fetch_taxa_by_book(by_book, opts) do
    books =
      from(book in Book,
        where: ^Utils.tuple_in([:slug, :version], Map.keys(by_book))
      )
      |> Query.Book.select_signature()
      |> Ornitho.Repo.all()

    books
    |> Enum.reduce(%{}, fn book, acc ->
      grouped =
        Query.Taxon.by_book(book)
        |> Query.Taxon.select_by_format(opts[:format])
        |> Query.Taxon.by_codes(by_book[{book.slug, book.version}])
        |> Ornitho.Repo.all()
        |> Ornitho.Repo.preload(:parent_species)
        |> Enum.map(fn taxon ->
          add_book_to_taxon_and_species(taxon, book)
        end)
        |> Enum.group_by(&Taxon.key/1)
        |> Map.new(fn {key, [val | _]} -> {key, val} end)

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
      # Keys that don't match the canonical "/slug/version/code" shape (e.g.
      # malformed or legacy values) simply don't resolve to a taxon and are
      # skipped here, leaving the corresponding lookup result as nil.
      case String.split(key, "/") do
        ["", book_slug, book_version, taxon_code] ->
          book_sig = {book_slug, book_version}
          list = acc[book_sig] || []
          Map.put(acc, book_sig, [taxon_code | list])

        _ ->
          acc
      end
    end)
  end

  def repo() do
    Application.fetch_env!(:ornithologue, :repo)
  end

  @doc """
  The database schema (Ecto prefix) the host app configured for Ornithologue
  tables, or `nil` for the connection default.
  """
  def prefix() do
    Application.get_env(:ornithologue, :prefix)
  end
end
