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
    |> Query.Taxon.ordered
    |> offset(^off)
    |> limit(^per_page)
    |> process_options(opts)
    |> Repo.all()
  end

  def search(book, search_term, opts \\ []) do
    limit = opts[:limit] || @search_results_limit

    Query.Taxon.base_taxon(book)
    |> Query.Taxon.ordered
    |> limit(^limit)
    |> Query.Taxon.search(search_term)
    |> process_options(opts)
    |> Repo.all()
  end

  defp process_options(query, opts) do
    Enum.reduce(opts, query, fn {key, val}, newquery ->
      case key do
        :with_parent_species ->
          case val do
            true -> Query.Taxon.with_parent_species(newquery)
            _ -> newquery
          end
        _ -> newquery
      end
    end)
  end
end
