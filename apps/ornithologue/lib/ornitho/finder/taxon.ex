defmodule Ornitho.Finder.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

  import Ecto.Query

  alias Ornitho.Query
  alias Ornitho.Schema.{Book, Taxon}

  @default_per_page 25
  @search_results_limit 10

  @spec by_name_sci(Book.t(), String.t()) :: Taxon.t() | nil
  def by_name_sci(book, name_sci) do
    Query.Taxon.base_taxon(book)
    |> where(name_sci: ^name_sci)
    |> repo().one()
  end

  @spec by_code(Book.t(), String.t()) :: Taxon.t() | nil
  def by_code(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> repo().one()
  end

  def by_codes(book, codes) do
    Query.Taxon.base_taxon(book)
    |> where([t], t.code in ^codes)
    |> repo().all()
  end

  def by_code!(book, code) do
    Query.Taxon.base_taxon(book)
    |> where(code: ^code)
    |> repo().one!()
  end

  def page(book, page_num, opts \\ []) do
    per_page = opts[:per_page] || @default_per_page
    off = per_page * (page_num - 1)

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered()
    |> offset(^off)
    |> limit(^per_page)
    |> repo().all()
  end

  def search(book, search_term, opts \\ []) do
    limit = opts[:limit] || @search_results_limit

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered()
    |> limit(^limit)
    |> Query.Taxon.search(search_term)
    |> repo().all()
  end

  def with_parent_species(taxon_or_taxa) do
    taxon_or_taxa
    |> repo().preload(:parent_species)
  end

  def with_child_taxa(taxon_or_taxa) do
    taxon_or_taxa
    |> repo().preload(:child_taxa)
  end

  defp repo() do
    Application.fetch_env!(:ornithologue, :repo)
  end
end
