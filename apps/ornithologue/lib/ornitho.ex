defmodule Ornitho do
  @moduledoc """
  Functions for creating books and taxa.
  """

  alias Ornitho.Schema.{Book, Taxon}

  def create_book(book = %Book{}) do
    Book.creation_changeset(book, %{})
    |> Ornitho.Repo.insert()
  end

  def create_book(attrs = %{}) do
    Book.creation_changeset(%Book{}, attrs)
    |> Ornitho.Repo.insert()
  end
end
