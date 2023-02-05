defmodule Ornitho do
  @moduledoc """
  Functions for creating books and taxa.
  """

  alias Ornitho.Schema.{Book, Taxon}
  alias Ornitho.Query
  alias Ecto.Multi

  import Ecto.Query

  def find_book(slug, version) do
    base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.one
  end

  def create_book(%Book{} = book) do
    Book.creation_changeset(book, %{})
    |> Ornitho.Repo.insert()
  end

  def create_book(%{} = attrs) do
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
    from(Book, as: :book)
  end

  def create_taxon(book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornitho.Repo.insert()
  end

  def create_taxa(book, attrs_list) do
    attrs_list
    |> Enum.reduce(Multi.new, fn attrs, multi ->
      multi
      |> Multi.insert(attrs, Taxon.creation_changeset(book, attrs))
    end)
    |> Ornitho.Repo.transaction()
  end
end
