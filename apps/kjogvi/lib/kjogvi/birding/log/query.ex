defmodule Kjogvi.Birding.Log.Query do
  @moduledoc """
  Queries to build the log entry feed.

  For each (location, year_scope) combination we find the first-ever observation
  date per species — i.e., the date that species was "added" to that list.
  We then look at recent dates and report which species were added on each date.

  ## Query shape

  All scopes (World + each enabled location, total + year) are computed from a
  single scan of `observations ⨝ cards ⨝ species_taxa_mappings`. The base scan
  is cross-joined against an inline `unnest` of scope ids, filtered by card
  ancestry membership, and then collapsed with two `DISTINCT ON` queries
  (one for life firsts, one for year firsts) unioned together. This replaces
  the old shape, which scanned the base join `2 × (N + 1)` times for
  N enabled locations.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Observation
  alias Kjogvi.Birding.LifeObservation
  alias Kjogvi.Repo

  @doc false
  def firsts_in_range(scope, locations, {start_date, end_date}) do
    %{user: %{id: user_id}, include_private: include_private} = scope

    # Scope ids: nil represents the World scope. Each location id represents
    # a per-location scope (matched by ancestry: a card belongs to scope L
    # if its card.location_id == L or L is in card.location.ancestry).
    scope_ids = [nil | Enum.map(locations, & &1.id)]

    base_query =
      from o in Observation,
        as: :observation,
        join: c in assoc(o, :card),
        as: :card,
        join: stm in assoc(o, :species_taxa_mapping),
        as: :stm,
        join: cl in assoc(c, :location),
        as: :card_location,
        where: o.unreported == false and c.user_id == ^user_id

    base_query =
      if include_private do
        base_query
      else
        Observation.Query.exclude_hidden(base_query)
      end

    scoped_query = scoped_query(base_query, scope_ids)

    # Wrap each DISTINCT ON in a subquery so PostgreSQL keeps the inner
    # ORDER BY scoped to its own SELECT instead of attaching it to the union.
    total_firsts = from r in subquery(total_first_query(scoped_query)), select: r
    year_firsts = from r in subquery(year_first_query(scoped_query)), select: r

    union_query = union_all(total_firsts, ^year_firsts)

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
      where: r.observ_date >= ^start_date,
      order_by: [desc: r.observ_date]
    )
    |> then(fn query ->
      if end_date do
        query
        |> where([r], r.observ_date <= ^end_date)
      else
        query
      end
    end)
    |> Repo.all()
  end

  # Cross-join the base join against the list of scope ids and keep only
  # rows where the card belongs to that scope (World matches every card;
  # a location scope matches when card.location_id == scope or the scope
  # appears in the card location's ancestry).
  defp scoped_query(base_query, scope_ids) do
    from [observation: o, card: c, stm: stm, card_location: cl] in base_query,
      inner_lateral_join:
        s in fragment("SELECT * FROM unnest(?::bigint[]) AS scope_id", ^scope_ids),
      on: true,
      where:
        is_nil(s.scope_id) or s.scope_id == c.location_id or
          fragment("? = ANY(?)", s.scope_id, cl.ancestry),
      select: %{
        species_page_id: stm.species_page_id,
        observ_date: c.observ_date,
        start_time: c.start_time,
        obs_id: o.id,
        card_id: c.id,
        location_id: c.location_id,
        cached_year: c.cached_year,
        scope_id: s.scope_id
      }
  end

  # First observation per (species, scope) — life first.
  defp total_first_query(scoped_query) do
    from r in subquery(scoped_query),
      distinct: [r.species_page_id, r.scope_id],
      order_by: [
        asc: r.species_page_id,
        asc: r.scope_id,
        asc: r.observ_date,
        asc_nulls_last: r.start_time,
        asc: r.obs_id
      ],
      select: %{
        species_page_id: r.species_page_id,
        observ_date: r.observ_date,
        start_time: r.start_time,
        obs_id: r.obs_id,
        card_id: r.card_id,
        location_id: r.location_id,
        location_id_scope: r.scope_id,
        year_scope: fragment("NULL::integer")
      }
  end

  # First observation per (species, scope, year) — year first.
  defp year_first_query(scoped_query) do
    from r in subquery(scoped_query),
      distinct: [r.species_page_id, r.scope_id, r.cached_year],
      order_by: [
        asc: r.species_page_id,
        asc: r.scope_id,
        asc: r.cached_year,
        asc: r.observ_date,
        asc_nulls_last: r.start_time,
        asc: r.obs_id
      ],
      select: %{
        species_page_id: r.species_page_id,
        observ_date: r.observ_date,
        start_time: r.start_time,
        obs_id: r.obs_id,
        card_id: r.card_id,
        location_id: r.location_id,
        location_id_scope: r.scope_id,
        year_scope: r.cached_year
      }
  end

  @doc false
  def preload_life_observations(rows) do
    species_page_ids = rows |> Enum.map(& &1.species_page_id) |> Enum.uniq()

    species_pages =
      from(p in Kjogvi.Pages.Species, where: p.id in ^species_page_ids)
      |> Repo.all()
      |> Map.new(&{&1.id, &1})

    Enum.map(rows, fn row ->
      life_obs = %LifeObservation{
        id: row.obs_id,
        species_page_id: row.species_page_id,
        species_page: species_pages[row.species_page_id]
      }

      Map.put(row, :life_observation, life_obs)
    end)
  end
end
