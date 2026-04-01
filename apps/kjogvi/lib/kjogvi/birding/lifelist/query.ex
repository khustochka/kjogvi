defmodule Kjogvi.Birding.Lifelist.Query do
  @moduledoc """
  Queries to build lifelist.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Birding.Lifelist.Filter
  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.Observation

  @typep filter_or_keyword() :: Lifelist.filter() | keyword()

  @doc """
  Full query to generate lifelist.
  """
  @spec lifelist_query(Lifelist.Scope.t()) :: Ecto.Query.t()
  @spec lifelist_query(Lifelist.Scope.t(), filter_or_keyword()) :: Ecto.Query.t()
  @spec lifelist_query(Lifelist.Scope.t(), filter_or_keyword(), keyword()) :: Ecto.Query.t()
  def lifelist_query(scope, filter \\ [], opts \\ []) do
    query =
      from l in subquery(lifers_query(scope, filter)),
        order_by: [desc: l.observ_date, desc_nulls_last: l.start_time, desc: l.id],
        limit: ^opts[:limit]

    case opts[:excluding_species] do
      nil -> query
      ids -> where(query, [l], l.species_page_id not in ^ids)
    end
  end

  defp lifers_query(scope, filter) do
    from [o, c, stm] in observations_filtered(scope, filter),
      distinct: stm.species_page_id,
      order_by: [
        asc: stm.species_page_id,
        asc: c.observ_date,
        asc_nulls_last: c.start_time,
        asc: o.id
      ],
      select: %{
        id: o.id,
        card_id: c.id,
        species_page_id: stm.species_page_id,
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

        {:motorless, true} ->
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

  @doc """
  Query returning distinct years from filtered observations.
  """
  def years_query(scope, filter) do
    observations_filtered(scope, filter)
    |> distinct(true)
    |> select([_o, c], c.cached_year)
  end

  @doc """
  Query returning distinct months from filtered observations.
  """
  def months_query(scope, filter) do
    observations_filtered(scope, filter)
    |> distinct(true)
    |> select([_o, c], c.cached_month)
  end

  @doc """
  Query returning IDs of lifelist locations (those with `public_index` set)
  that have observations matching the given filter.
  """
  def location_ids_query(scope, filter) do
    card_location_ids =
      observations_filtered(scope, filter)
      |> distinct(true)
      |> select([_o, c], c.location_id)

    ancestor_ids =
      from(cl in Kjogvi.Geo.Location,
        where: cl.id in subquery(card_location_ids),
        select: fragment("unnest(?)", cl.ancestry)
      )

    special_parent_ids =
      from(cl in Kjogvi.Geo.Location,
        where: cl.id in subquery(card_location_ids),
        join: sl in "special_locations",
        on:
          field(sl, :child_location_id) == cl.id or
            field(sl, :child_location_id) in cl.ancestry,
        distinct: true,
        select: field(sl, :parent_location_id)
      )

    from(ll in Kjogvi.Geo.Location,
      where: not is_nil(ll.public_index),
      where:
        ll.id in subquery(card_location_ids) or
          ll.id in subquery(ancestor_ids) or
          ll.id in subquery(special_parent_ids),
      select: ll.id
    )
  end

  defp observation_base(scope) do
    %{user: %{id: user_id}, include_private: include_private} = scope

    query =
      from o in Observation,
        as: :observation,
        join: c in assoc(o, :card),
        as: :card,
        join: stm in assoc(o, :species_taxa_mapping),
        where: o.unreported == false and c.user_id == ^user_id

    if include_private do
      query
    else
      Observation.Query.exclude_hidden(query)
    end
  end
end
