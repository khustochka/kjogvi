defmodule Ornitho.Query.Taxon do
  @moduledoc """
  Queries for Taxa.
  """

  import Ecto.Query

  alias Ornitho.Schema.Taxon

  @select_minimal [
    :id,
    :book_id,
    :code,
    :name_sci,
    :name_en,
    :category,
    :sort_order,
    :parent_species_id,
    :order,
    :family
  ]

  def by_book(query \\ Taxon, book) do
    from(query)
    |> where(book_id: ^book.id)
  end

  def by_codes(query, codes) do
    from(query)
    |> where([t], t.code in ^codes)
  end

  def select_minimal(query) do
    from(query)
    |> select(^@select_minimal)
  end

  def ordered(query) do
    query
    |> order_by(^Taxon.default_order())
  end

  def base_ordered(book) do
    by_book(book)
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
