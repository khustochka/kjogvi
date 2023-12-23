defmodule Kjogvi.Query.Card do
  @moduledoc """
  Queries for Cards.
  """

  import Ecto.Query

  alias Kjogvi.Query

  def by_year(query, year) when is_integer(year) do
    query
    |> where([..., c], type(fragment("EXTRACT(year from ?)", c.observ_date), :integer) == ^year)
  end

  # Performance is roughly the same but we avoid joining with locations
  def by_location_with_descendants(query, location) do
    child_ids =
      from(Query.Location.child_locations(location))
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
