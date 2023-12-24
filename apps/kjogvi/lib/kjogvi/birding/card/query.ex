defmodule Kjogvi.Birding.Card.Query do
  @moduledoc """
  Queries for Cards.
  """

  import Ecto.Query
  import Kjogvi.Query.API

  alias Kjogvi.Geo

  def by_year(query, year) when is_integer(year) do
    query
    |> where([..., c], extract_year(c.observ_date) == ^year)
  end

  def by_location_with_descendants(query, %{location_type: "special", id: id}) do
    specials_ids =
      from("special_locations")
      |> where([l], l.parent_location_id == ^id)
      |> select([l], l.child_location_id)

    child_ids =
      from(Geo.Location)
      |> join(:inner, [l], s in subquery(specials_ids), on: s.child_location_id == l.id or s.child_location_id in l.ancestry)
      |> select([l], l.id)

    from [..., c] in query,
      where: c.location_id in subquery(child_ids)
  end

  # Performance is roughly the same but we avoid joining with locations
  def by_location_with_descendants(query, location) do
    child_ids =
      from(Geo.Location.Query.child_locations(location))
      |> select([l], l.id)

    from [..., c] in query,
      where: c.location_id in subquery(child_ids)
  end

  # defp filter_by_location(query, %{id: id, location_type: "country"}) do
  #   from [_, c] in query,
  #     join: l in assoc(c, :location),
  #     where: l.country_id == ^id or l.id == ^id
  # end

  # defp filter_by_location(query, %{id: id}) do
  #   from [_, c] in query,
  #     join: l in assoc(c, :location),
  #     where: ^id in l.ancestry or l.id == ^id
  # end

  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      group_by: c.id,
      select_merge: %{observation_count: count(obs.id)}
    )
  end
end
