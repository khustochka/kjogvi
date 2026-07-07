defmodule Ornitho.Ops.Taxon do
  @moduledoc """
  Functions for operations with taxa.
  """

  alias Ornitho.Schema.Book
  alias Ornitho.Schema.Taxon
  alias Ecto.Multi

  def create(%Book{} = book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornitho.Repo.insert()
  end

  def create!(%Book{} = book, attrs) do
    Taxon.creation_changeset(book, attrs)
    |> Ornitho.Repo.insert!()
  end

  def create_many(%Book{} = book, attrs_list) do
    attrs_list
    |> Enum.reduce(Multi.new(), fn attrs, multi ->
      multi
      # Transaction options don't reach Multi operations, so the prefix
      # has to be attached to each insert.
      |> Multi.insert(attrs, Taxon.creation_changeset(book, attrs), Ornitho.Repo.default_opts())
    end)
    |> Ornitho.Repo.transaction()
  end

  def update_taxon(taxon, attrs) do
    Taxon.updating_changeset(taxon, attrs)
    |> Ornitho.Repo.update()
  end

  @doc """
  Links every child taxon in a book to its parent species in a single statement.

  Each child carries its parent's code in `extras->>'parent_species_code'` (stashed
  there at import time, since the parent's id is not known while rows are streamed in).
  This resolves those codes to ids in one self-join over the book. Children whose
  parent code has no matching taxon are left unlinked. On success returns
  `{:ok, count}` with the number of taxa updated; on a database error returns
  `{:error, reason}`.
  """
  def link_parent_species(book_id) do
    taxa = Ornitho.Repo.qualified("taxa")

    query = """
    UPDATE #{taxa} AS child
    SET parent_species_id = parent.id
    FROM #{taxa} AS parent
    WHERE child.book_id = $1
      AND parent.book_id = $1
      AND parent.code = child.extras->>'parent_species_code'
    """

    # The taxa were just bulk-inserted in this same transaction, so the planner has no
    # statistics for them and would otherwise pick a disastrous nested-loop plan for the
    # self-join (seconds instead of tens of milliseconds). Refresh stats first.
    with {:ok, _} <- Ornitho.Repo.query("ANALYZE #{taxa}", []),
         {:ok, %{num_rows: count}} <- Ornitho.Repo.query(query, [book_id]) do
      {:ok, count}
    end
  end
end
