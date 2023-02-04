defmodule Ornitho do
  @moduledoc """
  Functions for creating books and taxa.
  """

  alias Ornitho.Schema.{Book, Taxon}
  alias Ornitho.Query

  import Ecto.Query

  def create_book(book = %Book{}) do
    Book.creation_changeset(book, %{})
    |> Ornitho.Repo.insert()
  end

  def create_book(attrs = %{}) do
    Book.creation_changeset(%Book{}, attrs)
    |> Ornitho.Repo.insert()
  end

  def book_exists?(%{slug: slug, version: version}) do
    book_exists?(slug, version)
  end

  def book_exists?(slug, version) do
    base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.exists?()
  end

  def delete_book(%{slug: slug, version: version}) do
    delete_book(slug, version)
  end

  def delete_book(slug, version) do
    base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.delete_all()
  end

  defp base_book() do
    from Book, as: :book
  end
 end
