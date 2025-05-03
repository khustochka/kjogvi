defmodule Ornitho.Ops.Taxon do
  @moduledoc """
  Functions for operations with taxa.
  """

  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon
  alias Ecto.Multi

  def create(%Book{} = book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornithologue.repo().insert()
  end

  def create!(%Book{} = book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornithologue.repo().insert!()
  end

  def create_many(%Book{} = book, attrs_list) do
    attrs_list
    |> Enum.reduce(Multi.new(), fn attrs, multi ->
      multi
      |> Multi.insert(attrs, Taxon.creation_changeset(book, attrs))
    end)
    |> Ornithologue.repo().transaction()
  end

  # def update_taxon(taxon, attrs) do
  #   Taxon.updating_changeset(taxon, attrs)
  #   |> Ornithologue.repo().update()
  # end
end
