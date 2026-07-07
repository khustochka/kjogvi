defmodule Ornitho.Ops.Book do
  @moduledoc """
  Operations with books
  """

  alias Ornitho.Schema.Book
  alias Ornitho.Query

  # def create(%Book{} = book) do
  #   Book.creation_changeset(book, %{})
  #   |> Ornitho.Repo.insert()
  # end

  def create(%{} = attrs) do
    Book.creation_changeset(%Book{}, attrs)
    |> Ornitho.Repo.insert()
  end

  def finalize_imported_book(book, taxa_count) do
    book
    |> Book.finalize_changeset(taxa_count: taxa_count)
    |> Ornitho.Repo.update()
  end

  def delete(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.delete_all()
  end
end
