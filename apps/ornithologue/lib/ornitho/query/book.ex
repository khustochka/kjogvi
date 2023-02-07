defmodule Ornitho.Query.Book do
  @moduledoc """
  Queries for Books.
  """

  import Ecto.Query

  @spec by_signature(Ecto.Queryable.t(), String.t(), String.t()) :: Ecto.Query.t()
  def by_signature(query, slug, version) do
    from([..., book: b] in query,
      where: b.slug == ^slug and b.version == ^version
    )
  end

  @spec by_signature(Ecto.Queryable.t(), %{
          :slug => String.t(),
          :version => String.t(),
          optional(any) => any
        }) ::
          Ecto.Query.t()
  def by_signature(query, %{slug: slug, version: version}) do
    by_signature(query, slug, version)
  end
end
