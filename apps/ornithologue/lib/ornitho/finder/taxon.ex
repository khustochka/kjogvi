defmodule Ornitho.Finder.Taxon do
  @moduledoc """
  Functions for fetching Taxa.
  """

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

    base_query =
      Query.Taxon.base_taxon(book)
      |> order_by(:sort_order)
      |> offset(^off)
      |> limit(^per_page)

    query = if opts[:with_parent_species] do
      base_query |> preload(:parent_species)
    else
      base_query
    end

    query
    |> Repo.all()
  end
end
