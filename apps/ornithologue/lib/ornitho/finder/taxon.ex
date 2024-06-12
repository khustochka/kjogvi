defmodule Ornitho.Finder.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

  import Ecto.Query

  alias Ornitho.Query
  alias Ornitho.Schema.{Book, Taxon}

  @search_results_limit 10

  @spec by_name_sci(Book.t(), String.t()) :: Taxon.t() | nil
  def by_name_sci(book, name_sci) do
    Query.Taxon.base_taxon(book)
    |> where(name_sci: ^name_sci)
    |> Ornithologue.repo().one()
  end

  @spec by_code(Book.t(), String.t()) :: Taxon.t() | nil
  def by_code(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> Ornithologue.repo().one()
  end

  def by_codes(book, codes) do
    Query.Taxon.base_taxon(book)
    |> where([t], t.code in ^codes)
    |> Ornithologue.repo().all()
  end

  def by_code!(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> Ornithologue.repo().one!()
  end

  def search(book, search_term, opts \\ []) do
    limit = opts[:limit] || @search_results_limit

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered()
    |> limit(^limit)
    |> Query.Taxon.search(search_term)
    |> Ornithologue.repo().all()
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
