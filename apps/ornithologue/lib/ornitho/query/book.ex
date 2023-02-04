defmodule Ornitho.Query.Book do
  @moduledoc """
  Queries for Books.
  """

  import Ecto.Query

  def by_signature(query, slug, version) do
    from [..., book: b] in query,
    where: b.slug == ^slug and b.version == ^version
  end

  def by_signature(query, slug, version) do
    from [..., book: b] in query,
    where: b.slug == ^slug and b.version == ^version
  end
end
