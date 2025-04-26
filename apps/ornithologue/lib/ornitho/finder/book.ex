defmodule Ornitho.Finder.Book do
  @moduledoc """
  Functions for fetching Books.
  """

  alias Ornitho.Query
  alias Ornitho.Schema.Book

  import Ecto.Query

  def all() do
    Query.Book.base_book()
    |> Query.Book.ordered()
    |> Ornithologue.repo().all()
  end

  def all_signatures() do
    Query.Book.base_book()
    |> select([b], [b.slug, b.version])
    |> Ornithologue.repo().all()
  end

  @spec by_signature(String.t(), String.t()) :: Book.t() | nil
  def by_signature(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornithologue.repo().one()
  end

  def by_signature!(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornithologue.repo().one!()
  end

  def exists?(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornithologue.repo().exists?()
  end
end
