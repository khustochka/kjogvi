defmodule Ornitho.Finder.Book do
  @moduledoc """
  Functions for fetching Books.
  """

  alias Ornitho.Repo
  alias Ornitho.Query
  alias Ornitho.Schema.Book

  def all() do
    Query.Book.base_book()
    |> Repo.all()
  end

  def with_taxa_count() do
    Query.Book.base_book()
    |> Query.Book.with_taxa_count()
    |> Repo.all()
  end

  @spec by_signature(String.t(), String.t()) :: Book.t() | nil
  def by_signature(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Repo.one()
  end

  def exists?(%{slug: slug, version: version}) do
    exists?(slug, version)
  end

  def exists?(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.exists?()
  end
end
