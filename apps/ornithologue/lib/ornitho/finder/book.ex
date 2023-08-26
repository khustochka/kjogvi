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

  @spec load_taxa_count(Book.t()) :: Book.t()
  def load_taxa_count(book) do
    taxa_count =
      Ecto.assoc(book, :taxa)
      |> Repo.aggregate(:count)

    %{book | taxa_count: taxa_count}
  end

  def exists?(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.exists?()
  end
end
