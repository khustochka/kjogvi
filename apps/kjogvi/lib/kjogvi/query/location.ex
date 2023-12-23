defmodule Kjogvi.Query.Location do
  @moduledoc """
  Queries for Locations.
  """

  @country_location_type "country"
  @special_location_type "special"

  import Ecto.Query

  alias Kjogvi.Geo.Location

  def by_slug(query, slug) do
    from l in query, where: l.slug == ^slug
  end

  def countries(query) do
    from [..., l] in query,
      where: l.location_type == @country_location_type
  end

  def specials(query) do
    from [..., l] in query,
      where: l.location_type == @special_location_type
  end

  def load_cards_count(query) do
    from l in query,
      left_join: c in assoc(l, :cards),
      group_by: l.id,
      select_merge: %{cards_count: count(c.id)}
  end

  def child_locations(%{id: id}) do
    from l in Location,
      where: ^id in l.ancestry or ^id == l.id
  end
end
