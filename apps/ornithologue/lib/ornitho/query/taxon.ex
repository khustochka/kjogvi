defmodule Ornitho.Query.Taxon do
  @moduledoc """
  Queries for Taxa.
  """

  import Ecto.Query

  alias Ornitho.Schema.Taxon

  def base_taxon(book) do
    from(Taxon, as: :taxon)
    |> where(book_id: ^book.id)
  end

  def ordered(query) do
    query
    |> order_by(^Taxon.default_order())
  end

  def base_ordered(book) do
    base_taxon(book)
    |> ordered()
  end

  def with_parent_species(query) do
    query
    |> preload(:parent_species)
  end

  def search(query, search_term) do
    sanitized_term = Ornitho.Query.Utils.sanitize_like(search_term)
    start_term = "#{sanitized_term}%"
    like_term = "%#{sanitized_term}%"

    query
    |> where(
      [t],
      ilike(t.name_sci, ^like_term) or ilike(t.name_en, ^like_term) or ilike(t.code, ^start_term)
    )
  end
end
