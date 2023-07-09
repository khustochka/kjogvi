defmodule Ornitho.Finder.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

  @search_results_limit 10

  import Ecto.Query

  alias Ornitho.Repo
  alias Ornitho.Query
  alias Ornitho.Schema.{Book, Taxon}

  @default_per_page 25

  @spec by_name_sci(Book.t(), String.t()) :: Taxon.t() | nil
  def by_name_sci(book, name_sci) do
    Query.Taxon.base_taxon(book)
    |> where(name_sci: ^name_sci)
    |> Repo.one()
  end

  def page(book, page_num, opts \\ []) do
    per_page = opts[:per_page] || @default_per_page
    off = per_page * (page_num - 1)

    Query.Taxon.base_taxon(book)
    |> order_by(:sort_order)
    |> offset(^off)
    |> limit(^per_page)
    |> maybe_preload_parent_species(opts[:with_parent_species])
    |> Repo.all()
  end

  def search(book, search_term, opts \\ []) do
    limit = opts[:limit] || @search_results_limit
    start_term = "#{search_term}%"
    like_term = "%#{search_term}%"

    Query.Taxon.base_taxon(book)
    |> order_by(:sort_order)
    |> limit(^limit)
    |> where([t], ilike(t.name_sci, ^like_term))
    |> or_where([t], ilike(t.name_en, ^like_term))
    |> or_where([t], ilike(t.code, ^start_term))
    |> maybe_preload_parent_species(opts[:with_parent_species])
    |> Repo.all()
  end

  defp maybe_preload_parent_species(query, true) do
    query
    |> preload(:parent_species)
  end

  defp maybe_preload_parent_species(query, x) when x == false or is_nil(x) do
    query
  end
end
