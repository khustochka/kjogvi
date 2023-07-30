defmodule Ornitho.Finder.Book do
  @moduledoc """
  Functions for fetching Books.
  """

  alias Ornitho.Repo
  alias Ornitho.Query
  alias Ornitho.Schema.Book

  def all() do
    Query.Book.base_book()
    |> Query.Book.ordered()
    |> Repo.all()
  end

  def with_taxa_count() do
    Query.Book.base_book()
    |> Query.Book.ordered()
    |> Query.Book.with_taxa_count()
    |> Repo.all()
  end

  @spec by_signature(String.t(), String.t()) :: Book.t() | nil
  def by_signature(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Repo.one()
  end

  def by_signature!(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Repo.one!()
  end

  @spec taxa_count(Book.t()) :: Integer
  def taxa_count(book) do
    Ecto.assoc(book, :taxa)
    |> Repo.aggregate(:count)
  end

  def exists?(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.exists?()
  end
end
