defmodule Kjogvi.Geo.Location.Query do
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

  def for_user(query, nil) do
    from l in query, where: l.is_private == false or is_nil(l.is_private)
  end

  def for_user(query, _user) do
    query
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
