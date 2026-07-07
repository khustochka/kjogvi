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
    |> Ornitho.Repo.all()
  end

  def all_signatures() do
    Query.Book.base_book()
    |> select([b], [b.slug, b.version])
    |> Ornitho.Repo.all()
  end

  def all_importers() do
    Query.Book.base_book()
    |> select([b], b.importer)
    |> Ornitho.Repo.all()
  end

  @spec by_signature(String.t(), String.t()) :: Book.t() | nil
  def by_signature(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.one()
  end

  def by_signature!(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.one!()
  end

  def exists?(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.exists?()
  end
end
