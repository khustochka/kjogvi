defmodule Ornitho.Query.Taxon do
  @moduledoc """
  Queries for Taxa.
  """

  alias Ornitho.Schema.Taxon

  import Ecto.Query

  def base_taxon(book) do
    from(Taxon, as: :taxon)
    |> where(book_id: ^book.id)
  end

  def ordered(query) do
    query
    |> order_by(:sort_order)
  end
end
