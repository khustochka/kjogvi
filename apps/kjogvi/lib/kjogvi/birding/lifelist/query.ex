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
  def lifelist_query(scope, filter \\ [], opts \\ [])

  def lifelist_query(scope, %Filter{sort: :taxonomy} = filter, opts) do
    query =
      from l in subquery(lifers_query(scope, filter)),
        join: sp in Kjogvi.Pages.Species,
        on: sp.id == l.species_page_id,
        order_by: [asc: sp.sort_order, asc: l.id],
        limit: ^opts[:limit]

    apply_excluding_species(query, opts)
  end

  def lifelist_query(scope, %Filter{} = filter, opts) do
    query =
      from l in subquery(lifers_query(scope, filter)),
        order_by: [desc: l.observ_date, desc_nulls_last: l.start_time, desc: l.id],
        limit: ^opts[:limit]

    apply_excluding_species(query, opts)
  end

  def lifelist_query(scope, filter, opts) do
    lifelist_query(scope, Filter.discombo!(filter), opts)
  end

  defp apply_excluding_species(query, opts) do
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
    base = from([o, c] in Observation.Query.base_for_scope(scope))

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
  Query returning IDs of lifelist filter locations — the `country` and
  `subdivision1` rows that have observations matching the given filter, either
  directly or among their descendants.
  """
  def location_ids_query(scope, filter) do
    card_location_ids =
      observations_filtered(scope, filter)
      |> distinct(true)
      |> select([_o, c], c.location_id)

    # Each card location's level FK ancestors (`country_id … site_id`), unioned.
    ancestor_ids =
      Kjogvi.Geo.Location.level_fks()
      |> Enum.map(fn fk ->
        from(cl in Kjogvi.Geo.Location,
          where: cl.id in subquery(card_location_ids) and not is_nil(field(cl, ^fk)),
          select: field(cl, ^fk)
        )
      end)
      |> Enum.reduce(&union(&2, ^&1))

    from(ll in Kjogvi.Geo.Location,
      where: ll.location_type in [:country, :subdivision1],
      where:
        ll.id in subquery(card_location_ids) or
          ll.id in subquery(ancestor_ids),
      select: ll.id
    )
  end
end
