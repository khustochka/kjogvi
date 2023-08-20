defmodule Ornitho.Query.Book do
  @moduledoc """
  Queries for Books.
  """

  import Ecto.Query

  alias Ornitho.Schema.Book

  def ordered(query) do
    query
    |> order_by(^Book.default_order())
  end

  @spec by_signature(Ecto.Queryable.t(), String.t(), String.t()) :: Ecto.Query.t()
  def by_signature(query, slug, version) do
    from([..., book: b] in query,
      where: b.slug == ^slug and b.version == ^version
    )
  end

  def by_id(query, id) do
    from([..., book: b] in query,
      where: b.id == ^id
    )
  end

  def with_taxa_count(query) do
    from([..., book: b] in query,
      left_join: t in assoc(b, :taxa),
      group_by: b.id,
      select_merge: %{taxa_count: count(t.id)}
    )
  end

  def touch_imported_at(query) do
    query
    |> update(set: [imported_at: fragment("NOW()")])
  end

  def base_book() do
    from(Book, as: :book)
  end
end
