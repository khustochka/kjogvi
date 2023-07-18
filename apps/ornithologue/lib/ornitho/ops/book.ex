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

  def mark_book_imported(book) do
    Query.Book.base_book()
    |> Query.Book.by_id(book.id)
    |> Query.Book.touch_imported_at()
    |> Ornitho.Repo.update_all([])
  end

  def delete(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.delete_all()
  end
end
