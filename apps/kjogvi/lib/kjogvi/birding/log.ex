defmodule Kjogvi.Birding.Log do
  @moduledoc """
  Log: generates a feed of notable birding entries (species added to lists).

  For each date in the recent past, we compute which species were "added" to
  which lists (World total, Country total, Subdivision total, World year,
  Country year, Subdivision year). Entries are deduplicated so that if a species
  is a world lifer, we do not also report it as a new Canadian bird on the same day.

  ## Deduplication logic

  For a given species on a given date:
  1. Collect all (area, type) pairs where this date is the species' first date.
  2. Remove any pair whose ancestor area already appears in the set with
     the same or higher priority (total > year).

  Priority within a type: world > country > subdivision (by ancestry depth).
  """

  alias Kjogvi.Birding.Log.Cache
  alias Kjogvi.Birding.Log.Entry
  alias Kjogvi.Birding.Log.Query
  alias Kjogvi.Birding.Lifelist
  alias Kjogvi.Geo

  @default_limit 5
  @cutoff_days 93

  @doc """
  Returns log entries for the most recent days that have entries.

  Log settings are read from `scope.user.extras.log_settings`. Results for
  the public feed (`include_private: false`) are cached per
  `(user_id, limit, cutoff_days)` and the current date; cache entries are
  evicted when observations or `log_settings` change (see
  `Kjogvi.Birding.Log.Cache`). The private view bypasses the cache.

  Options:
  - `:limit` — max number of distinct dates to return (default #{@default_limit})
  - `:cutoff_days` — how many days back to look (default #{@cutoff_days})

  Returns a list of `{date, [%Entry{}]}` tuples, newest first.
  """
  @spec recent_entries(Lifelist.scope(), keyword()) :: [{Date.t(), [Entry.t()]}]
  def recent_entries(scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    cutoff_days = Keyword.get(opts, :cutoff_days, @cutoff_days)
    year = Keyword.get(opts, :year)

    filter =
      if year do
        [year: year]
      else
        [
          limit: limit,
          cutoff_days: cutoff_days
        ]
      end

    if scope.include_private do
      compute_recent_entries(scope, filter)
    else
      # Shortcut: since year filter is only used for private view, we only use
      # the cache with limit and cutoff_days filters, which are relevant for the public view.
      Cache.fetch(
        {scope.user.id, limit, cutoff_days},
        fn -> compute_recent_entries(scope, filter) end
      )
    end
  end

  defp compute_recent_entries(scope, filter) do
    limit = Keyword.get(filter, :limit)
    year = Keyword.get(filter, :year)

    {start_date, end_date} =
      if year do
        {Date.new!(year, 1, 1), Date.new!(year, 12, 31)}
      else
        {Date.add(Date.utc_today(), -Keyword.get(filter, :cutoff_days)), nil}
      end

    log_settings = scope.user.extras.log_settings

    location_ids =
      log_settings
      |> Enum.filter(&(&1.location_id && (&1.life || &1.year)))
      |> Enum.map(& &1.location_id)

    locations = Geo.get_locations_by_ids(location_ids)

    location_map = Map.new(locations, &{&1.id, &1})

    rows = Query.firsts_in_range(scope, locations, {start_date, end_date})

    if rows == [] do
      []
    else
      rows
      |> Query.preload_life_observations()
      |> build_entries(location_map, log_settings)
      |> filter_entries_by_settings(log_settings)
      |> then(fn entries ->
        if limit do
          Enum.take(entries, limit)
        else
          entries
        end
      end)
    end
  end

  @doc """
  Returns true if the user has any log entries enabled based on their settings.
  When no settings are configured, the log is disabled.
  """
  @spec any_enabled?(Lifelist.scope()) :: boolean()
  def any_enabled?(%{user: %{extras: %{log_settings: []}}}), do: false

  def any_enabled?(%{user: %{extras: %{log_settings: log_settings}}}) do
    Enum.any?(log_settings, fn setting ->
      setting.life || setting.year
    end)
  end

  # Filter built entries based on log_settings (removing specific type entries)
  defp filter_entries_by_settings(date_entries, []), do: date_entries

  defp filter_entries_by_settings(date_entries, log_settings) do
    settings_map = Map.new(log_settings, &{&1.location_id, &1})

    date_entries
    |> Enum.map(fn {date, entries} ->
      filtered =
        Enum.filter(entries, fn entry ->
          location_id = area_id(entry.area)

          case Map.get(settings_map, location_id) do
            nil ->
              true

            setting ->
              case entry.type do
                :life -> setting.life
                :year -> setting.year
              end
          end
        end)

      {date, filtered}
    end)
    |> Enum.reject(fn {_date, entries} -> entries == [] end)
  end

  # Group raw rows into {date, [entry]} tuples, applying deduplication.
  defp build_entries(rows, location_map, log_settings) do
    life_enabled_ids = life_enabled_area_ids(log_settings)

    rows
    |> Enum.group_by(& &1.observ_date)
    |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})
    |> Enum.map(fn {date, date_rows} ->
      entries =
        date_rows
        |> group_by_species()
        |> Enum.flat_map(fn {_species_page_id, species_rows} ->
          build_species_primaries(species_rows, location_map, life_enabled_ids)
        end)
        |> merge_primaries()

      {date, entries}
    end)
    |> Enum.reject(fn {_date, entries} -> entries == [] end)
  end

  # log_settings area_ids where :life is enabled. nil represents World.
  defp life_enabled_area_ids(log_settings) do
    log_settings
    |> Enum.filter(& &1.life)
    |> Enum.map(& &1.location_id)
    |> MapSet.new()
  end

  # Build the per-species primary candidates, each annotated with the
  # `:life` hit set (as [{area, list_total}]) that this primary also covers.
  # Returns a list of intermediate maps used by `merge_primaries/1`.
  defp build_species_primaries(rows, location_map, life_enabled_ids) do
    candidates =
      Enum.map(rows, fn row ->
        area = if row.location_id_scope, do: location_map[row.location_id_scope], else: nil
        type = if row.year_scope, do: :year, else: :life
        {area, type, row.year_scope, row.life_observation, row.list_total}
      end)

    {primaries, covered} = partition_candidates(candidates)

    # Only :life covered candidates become secondary annotations, and only
    # when the area is enabled for :life in log_settings.
    covered_life =
      covered
      |> Enum.filter(fn {area, type, _year, _obs, _total} ->
        type == :life and MapSet.member?(life_enabled_ids, area_id(area))
      end)
      |> Enum.map(fn {area, _type, _year, _obs, total} -> {area, total} end)

    Enum.map(primaries, fn {area, type, year, life_obs, list_total} ->
      # Covered :life annotations only apply to :life primaries.
      # A :year primary should not be annotated with life-scope secondaries.
      attached = if type == :life, do: covered_life, else: []

      %{
        type: type,
        area: area,
        year: year,
        life_obs: life_obs,
        list_total: list_total,
        covered_life: attached
      }
    end)
  end

  # Partition candidates into {primary, covered} based on ancestry priority.
  # Primary: survives dedup (not covered by any more significant candidate).
  # Covered: would have been dropped by the old dedup.
  defp partition_candidates(candidates) do
    total_area_ids =
      candidates
      |> Enum.filter(fn {_area, type, _year, _obs, _total} -> type == :life end)
      |> Enum.map(fn {area, _type, _year, _obs, _total} -> area_id(area) end)
      |> MapSet.new()

    year_area_ids =
      candidates
      |> Enum.filter(fn {_area, type, _year, _obs, _total} -> type == :year end)
      |> Enum.map(fn {area, _type, year, _obs, _total} -> {area_id(area), year} end)
      |> MapSet.new()

    Enum.split_with(candidates, fn {area, type, year, _obs, _total} ->
      not covered?(area, type, year, total_area_ids, year_area_ids)
    end)
  end

  # An entry is covered if the same area or any ancestor area has a
  # same-or-higher priority entry.
  # - A :life entry is covered if an ancestor has a :life.
  # - A :year entry is covered if self or ancestor has a :life,
  #   OR a strict ancestor has a :year for the same year.
  # "World" (nil area) has no ancestors. A world :year is covered if
  # world :life exists.
  defp covered?(area, type, year, total_area_ids, year_area_ids) do
    self_id = area_id(area)
    ancestor_ids = full_ancestor_chain(area)
    ids_to_check = [self_id | ancestor_ids]

    case type do
      :life ->
        Enum.any?(ancestor_ids, &MapSet.member?(total_area_ids, &1))

      :year ->
        has_covering_total =
          Enum.any?(ids_to_check, &MapSet.member?(total_area_ids, &1))

        has_covering_year =
          Enum.any?(ancestor_ids, &MapSet.member?(year_area_ids, {&1, year}))

        has_covering_total or has_covering_year
    end
  end

  # Returns the full ancestor chain for an area, including implicit World (nil).
  defp full_ancestor_chain(nil), do: []
  defp full_ancestor_chain(area), do: [nil | area.ancestry]

  defp area_id(nil), do: nil
  defp area_id(%{id: id}), do: id

  defp group_by_species(rows) do
    Enum.group_by(rows, & &1.species_page_id)
  end

  # Merge per-species primary candidates into final entries. Species are
  # grouped by (type, primary area, year, set of covered :life area ids) so
  # that a single %Entry{} only contains species sharing the same profile of
  # covered secondaries. For each merged entry the `list_total` at the
  # primary area and the list_totals at each covered area are the max across
  # the group — i.e. the count after the latest species in the group.
  defp merge_primaries(primaries) do
    primaries
    |> Enum.group_by(fn p ->
      covered_ids = p.covered_life |> Enum.map(fn {a, _} -> area_id(a) end) |> Enum.sort()
      {p.type, area_id(p.area), p.year, covered_ids}
    end)
    |> Enum.map(fn {{type, _area_id, year, _covered_ids}, group} ->
      head = hd(group)
      life_obs = Enum.map(group, & &1.life_obs)
      list_total = group |> Enum.map(& &1.list_total) |> Enum.max()
      covered_areas = merge_covered(group)

      %Entry{
        type: type,
        area: head.area,
        year: year,
        life_observations: life_obs,
        list_total: list_total,
        covered_areas: covered_areas
      }
    end)
    |> Enum.sort_by(&entry_sort_key/1)
  end

  # Across a group of species that share the same covered-area set, compute
  # the max list_total per covered area (i.e. the total after the latest
  # species in the group was added for that area).
  defp merge_covered(group) do
    group
    |> Enum.flat_map(& &1.covered_life)
    |> Enum.group_by(fn {area, _total} -> area_id(area) end)
    |> Enum.map(fn {_id, entries} ->
      {area, _} = hd(entries)
      max_total = entries |> Enum.map(fn {_a, t} -> t end) |> Enum.max()
      {area, max_total}
    end)
    |> Enum.sort_by(fn {area, _} -> length(area.ancestry) end)
  end

  # Sort entries: total before year, world before country before subdivision.
  defp entry_sort_key(%Entry{type: type, area: area, year: year}) do
    type_order = if type == :life, do: 0, else: 1
    depth = if area, do: length(area.ancestry), else: 0
    {type_order, depth, year}
  end
end
