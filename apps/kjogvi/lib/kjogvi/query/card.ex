defmodule Kjogvi.Query.Card do
  @moduledoc """
  Queries for Cards.
  """

  import Ecto.Query

  # alias Kjogvi.Birding.Card

  def by_year(query, year) when is_integer(year) do
    query
    |> where(fragment("EXTRACT(year from observ_date)::integer = ?", ^year))
  end

  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      group_by: c.id,
      select_merge: %{observation_count: count(obs.id)}
    )
  end
end
