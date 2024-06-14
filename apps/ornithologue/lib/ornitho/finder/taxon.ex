defmodule Ornitho.Finder.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

  import Ecto.Query

  alias Ornitho.Query
  alias Ornitho.Schema.{Book, Taxon}

  @search_results_limit 10
  @default_page_size 25

  @doc "Find a taxon in a book by scientific name"
  @spec by_name_sci(Book.t(), String.t()) :: Taxon.t() | nil
  def by_name_sci(book, name_sci) do
    Query.Taxon.base_taxon(book)
    |> where(name_sci: ^name_sci)
    |> Ornithologue.repo().one()
  end

  @doc "Find a taxon in a book by code"
  @spec by_code(Book.t(), String.t()) :: Taxon.t() | nil
  def by_code(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> Ornithologue.repo().one()
  end

  @doc "Find a taxon in a book by code, raise if not found"
  def by_code!(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> Ornithologue.repo().one!()
  end

  @doc "Find taxa in a book by a list of codes"
  def by_codes(book, codes) do
    Query.Taxon.base_taxon(book)
    |> where([t], t.code in ^codes)
    |> Ornithologue.repo().all()
  end

  @doc "Search for taxa in a book that match a search term"
  def search(book, search_term, opts \\ []) do
    limit = opts[:limit] || @search_results_limit

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered()
    |> limit(^limit)
    |> Query.Taxon.search(search_term)
    |> Ornithologue.repo().all()
  end

  @doc "Return a specified page in the list of taxa from a book"
  def paginate(book, opts \\ []) do
    page = opts[:page] || 1
    page_size = opts[:page_size] || @default_page_size

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered()
    |> Ornithologue.repo().paginate(page: page, page_size: page_size)
  end

  def with_parent_species(result = %Scrivener.Page{entries: entries}) do
    %Scrivener.Page{result | entries: with_parent_species(entries)}
  end

  def with_parent_species(taxon_or_taxa) do
    taxon_or_taxa
    |> Ornithologue.repo().preload(:parent_species)
  end

  def with_child_taxa(taxon_or_taxa) do
    taxon_or_taxa
    |> Ornithologue.repo().preload(:child_taxa)
  end
end
