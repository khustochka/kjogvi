defmodule Kjogvi.Birding.Lifelist.Query do
  @moduledoc """
  Queries to build lifelist.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Birding.Lifelist.Filter
  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.Observation

  @doc """
  Full query to generate lifelist.
  """
  @spec lifelist_query(Lifelist.Scope.t()) :: Ecto.Query.t()
  @spec lifelist_query(Lifelist.Scope.t(), Lifelist.filter()) :: Ecto.Query.t()
  def lifelist_query(scope, filter \\ []) do
    from l in subquery(lifers_query(scope, filter)),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query(scope, filter) do
    from [o, c] in observations_filtered(scope, filter),
      distinct: o.taxon_key,
      order_by: [asc: o.taxon_key, asc: c.observ_date, asc_nulls_last: c.start_time, asc: o.id],
      select: %{
        id: o.id,
        card_id: c.id,
        taxon_key: o.taxon_key,
        observ_date: c.observ_date,
        start_time: c.start_time,
        location_id: c.location_id
      }
  end

  @doc """
  Main entrypoint that converts filter into a query that returns observations matching it.
  """
  @spec observations_filtered(Lifelist.Scope.t()) :: Ecto.Query.t()
  @spec observations_filtered(Lifelist.Scope.t(), Lifelist.filter()) :: Ecto.Query.t()
  def observations_filtered(scope, filter \\ [])

  def observations_filtered(scope, %Filter{} = filter) do
    base = from([o, c] in observation_base(scope))

    Map.from_struct(filter)
    |> Enum.reduce(base, fn filter, query ->
      case filter do
        {:year, year} when not is_nil(year) ->
          Card.Query.by_year(query, year)

        {:month, month} when not is_nil(month) ->
          Card.Query.by_month(query, month)

        {:location, location} when not is_nil(location) ->
          Card.Query.by_location_with_descendants(query, location)

        {:motorless, motorless} when motorless == true ->
          Card.Query.motorless(query)

        {:exclude_heard_only, true} ->
          Observation.Query.exclude_heard_only(query)

        _ ->
          query
      end
    end)
  end

  def observations_filtered(user, filter) do
    filter |> Filter.discombo!() |> then(&observations_filtered(user, &1))
  end

  defp observation_base(scope) do
    %{user: %{id: user_id}, include_private: include_private} = scope

    query =
      from o in Observation,
        as: :observation,
        join: c in assoc(o, :card),
        as: :card,
        where: o.unreported == false and c.user_id == ^user_id

    if include_private do
      query
    else
      Observation.Query.exclude_hidden(query)
    end
  end
end
