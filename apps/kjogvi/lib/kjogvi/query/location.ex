defmodule Kjogvi.Query.Location do
  @moduledoc """
  Queries for Locations.
  """

  import Ecto.Query

  def by_slug(query, slug) do
    from l in query, where: l.slug == ^slug
  end

  def load_cards_count(query) do
    from(l in query,
      left_join: c in assoc(l, :cards),
      group_by: l.id,
      select_merge: %{cards_count: count(c.id)}
    )
  end
end
