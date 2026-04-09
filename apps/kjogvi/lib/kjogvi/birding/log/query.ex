defmodule Kjogvi.Birding.Log.Query do
  @moduledoc """
  Queries to build the log entry feed.

  For each (location, year_scope) combination we find the first-ever observation
  date per species — i.e., the date that species was "added" to that list.
  We then look at recent dates and report which species were added on each date.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @doc false
  def firsts_in_range(scope, locations, since_date) do
    %{user: %{id: user_id}, include_private: include_private} = scope

    base_query =
      from o in Observation,
        as: :observation,
        join: c in assoc(o, :card),
        as: :card,
        join: stm in assoc(o, :species_taxa_mapping),
        where: o.unreported == false and c.user_id == ^user_id

    base_query =
      if include_private do
        base_query
      else
        Observation.Query.exclude_hidden(base_query)
      end

    # Build per-location subqueries: for each location (nil = world), find the
    # first observation date per (species_page_id, year_scope).
    # We union all these together.

    location_queries =
      [nil | locations]
      |> Enum.flat_map(fn location ->
        loc_query = filter_by_location(base_query, location)

        # Wrap each DISTINCT ON query in subquery() so they can be used in UNION ALL.
        # PostgreSQL requires DISTINCT ON / ORDER BY queries inside UNION to be subqueries.
        total_subq = subquery(total_first_query(loc_query, location_id(location)))
        year_subq = subquery(year_first_query(loc_query, location_id(location)))

        [total_subq, year_subq]
      end)

    # Union all subqueries, add a cumulative species count per scope,
    # then filter to only rows where observ_date >= since_date.
    # The window function must run before the date filter so it counts
    # all species in the list, not just the recent ones.
    union_query = union_all_queries(location_queries)

    windowed_query =
      from(r in subquery(union_query),
        select: %{
          species_page_id: r.species_page_id,
          observ_date: r.observ_date,
          start_time: r.start_time,
          obs_id: r.obs_id,
          card_id: r.card_id,
          location_id: r.location_id,
          location_id_scope: r.location_id_scope,
          year_scope: r.year_scope,
          list_total:
            fragment(
              "COUNT(*) OVER (PARTITION BY ?, ? ORDER BY ?, ? NULLS LAST, ?)",
              r.location_id_scope,
              r.year_scope,
              r.observ_date,
              r.start_time,
              r.obs_id
            )
        }
      )

    from(r in subquery(windowed_query),
      where: r.observ_date >= ^since_date,
      order_by: [desc: r.observ_date]
    )
    |> Repo.all()
  end

  # --- Private helpers ---

  defp location_id(nil), do: nil
  defp location_id(%{id: id}), do: id

  defp filter_by_location(query, nil), do: query

  defp filter_by_location(query, location) do
    Card.Query.by_location_with_descendants(query, location)
  end

  # For a given base query, find the first observation date per species (all-time).
  # Returns rows: {species_page_id, observ_date, obs_id, card_id, loc_id, location_id_scope, year_scope}
  defp total_first_query(base_query, location_id_scope) do
    from([o, c, stm] in base_query,
      distinct: stm.species_page_id,
      order_by: [
        asc: stm.species_page_id,
        asc: c.observ_date,
        asc_nulls_last: c.start_time,
        asc: o.id
      ],
      select: %{
        species_page_id: stm.species_page_id,
        observ_date: c.observ_date,
        start_time: c.start_time,
        obs_id: o.id,
        card_id: c.id,
        location_id: c.location_id,
        location_id_scope: type(^location_id_scope, :integer),
        year_scope: fragment("NULL::integer")
      }
    )
  end

  # For a given base query, find the first observation date per species per year.
  # Returns rows with year_scope set.
  defp year_first_query(base_query, location_id_scope) do
    from([o, c, stm] in base_query,
      distinct: [stm.species_page_id, c.cached_year],
      order_by: [
        asc: stm.species_page_id,
        asc: c.cached_year,
        asc: c.observ_date,
        asc_nulls_last: c.start_time,
        asc: o.id
      ],
      select: %{
        species_page_id: stm.species_page_id,
        observ_date: c.observ_date,
        start_time: c.start_time,
        obs_id: o.id,
        card_id: c.id,
        location_id: c.location_id,
        location_id_scope: type(^location_id_scope, :integer),
        year_scope: c.cached_year
      }
    )
  end

  # When working with subqueries in a union, we select from the first subquery
  # and union_all the rest. Ecto's union_all macro works with subqueries too.
  defp union_all_queries([single]) do
    from(r in single, select: r)
  end

  defp union_all_queries([first | rest]) do
    base = from(r in first, select: r)

    Enum.reduce(rest, base, fn q, acc ->
      member = from(r in q, select: r)
      union_all(acc, ^member)
    end)
  end

  @doc false
  def preload_life_observations(rows) do
    obs_ids = Enum.map(rows, & &1.obs_id)

    obs_map =
      from(o in Observation,
        where: o.id in ^obs_ids,
        join: c in assoc(o, :card),
        join: stm in assoc(o, :species_taxa_mapping),
        select: %{
          id: o.id,
          card_id: c.id,
          species_page_id: stm.species_page_id,
          observ_date: c.observ_date,
          start_time: c.start_time,
          location_id: c.location_id
        }
      )
      |> Repo.all()
      |> Enum.map(&Repo.load(LifeObservation, &1))
      |> Location.Query.preload_all_locations()
      |> Repo.preload(:species_page)
      |> Map.new(&{&1.id, &1})

    Enum.map(rows, fn row -> Map.put(row, :life_observation, obs_map[row.obs_id]) end)
  end

  @doc """
  Returns locations with `public_index` set (countries and subdivisions used as
  log scopes).
  """
  def log_locations do
    from(l in Location,
      where: not is_nil(l.public_index),
      where: l.location_type in ["country", "region"],
      order_by: l.public_index
    )
    |> Repo.all()
  end
end
