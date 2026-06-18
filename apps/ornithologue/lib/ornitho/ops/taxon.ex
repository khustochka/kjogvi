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

  def update_taxon(taxon, attrs) do
    Taxon.updating_changeset(taxon, attrs)
    |> Ornithologue.repo().update()
  end

  @doc """
  Links every child taxon in a book to its parent species in a single statement.

  Each child carries its parent's code in `extras->>'parent_species_code'` (stashed
  there at import time, since the parent's id is not known while rows are streamed in).
  This resolves those codes to ids in one self-join over the book. Children whose
  parent code has no matching taxon are left unlinked. Returns the number of taxa
  updated.
  """
  def link_parent_species(book_id) do
    # The taxa were just bulk-inserted in this same transaction, so the planner has no
    # statistics for them and would otherwise pick a disastrous nested-loop plan for the
    # self-join (seconds instead of tens of milliseconds). Refresh stats first.
    Ornithologue.repo().query!("ANALYZE taxa", [])

    query = """
    UPDATE taxa AS child
    SET parent_species_id = parent.id
    FROM taxa AS parent
    WHERE child.book_id = $1
      AND parent.book_id = $1
      AND parent.code = child.extras->>'parent_species_code'
    """

    %{num_rows: count} = Ornithologue.repo().query!(query, [book_id])
    count
  end
end
