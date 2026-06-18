defmodule Ornitho.Ops.Taxon do
  @moduledoc """
  Functions for operations with taxa.
  """

  import Ecto.Query

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

  def update_taxon(taxon, attrs) do
    Taxon.updating_changeset(taxon, attrs)
    |> Ornithologue.repo().update()
  end

  @doc """
  Sets `parent_species_id` on all taxa whose code is in `child_codes` to the id of
  the taxon with code `parent_code`, scoped to `book_id`. Runs as a single statement
  per call without fetching rows. Returns the number of taxa updated.
  """
  def set_parent_species(book_id, parent_code, child_codes) do
    {count, _} =
      from(t in Taxon,
        where: t.book_id == ^book_id and t.code in ^child_codes,
        update: [
          set: [
            parent_species_id:
              fragment(
                "(SELECT id FROM taxa WHERE book_id = ? AND code = ?)",
                ^book_id,
                ^parent_code
              )
          ]
        ]
      )
      |> Ornithologue.repo().update_all([])

    count
  end
end
