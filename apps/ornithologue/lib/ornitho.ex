defmodule Ornitho do
  @moduledoc """
  Functions for creating books and taxa.
  """

  alias Ornitho.Schema.{Book, Taxon}
  alias Ornitho.Query
  alias Ecto.Multi

  def create_book(%Book{} = book) do
    Book.creation_changeset(book, %{})
    |> Ornitho.Repo.insert()
  end

  def create_book(%{} = attrs) do
    Book.creation_changeset(%Book{}, attrs)
    |> Ornitho.Repo.insert()
  end

  def mark_book_imported(book) do
    Query.Book.touch_imported_at(book)
    |> Ornitho.Repo.update_all([])
  end

  def delete_book(%{slug: slug, version: version}) do
    delete_book(slug, version)
  end

  def delete_book(slug, version) do
    Query.Book.base_book()
    |> Query.Book.by_signature(slug, version)
    |> Ornitho.Repo.delete_all()
  end

  def create_taxon(book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornitho.Repo.insert()
  end

  def create_taxon!(book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornitho.Repo.insert!()
  end

  def create_taxa(book, attrs_list) do
    attrs_list
    |> Enum.reduce(Multi.new(), fn attrs, multi ->
      multi
      |> Multi.insert(attrs, Taxon.creation_changeset(book, attrs))
    end)
    |> Ornitho.Repo.transaction()
  end

  def update_taxon(taxon, attrs) do
    Taxon.updating_changeset(taxon, attrs)
    |> Ornitho.Repo.update()
  end
end
