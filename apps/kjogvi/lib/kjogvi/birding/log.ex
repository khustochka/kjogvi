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

  alias Kjogvi.Birding.Log.Entry
  alias Kjogvi.Birding.Log.Query
  alias Kjogvi.Birding.Lifelist

  @default_limit 5
  @cutoff_days 93

  @doc """
  Returns log entries for the most recent days that have entries.

  Options:
  - `:limit` — max number of distinct dates to return (default #{@default_limit})
  - `:cutoff_days` — how many days back to look (default #{@cutoff_days})

  Returns a list of `{date, [%Entry{}]}` tuples, newest first.
  """
  @spec recent_entries(Lifelist.scope(), keyword()) :: [{Date.t(), [Entry.t()]}]
  def recent_entries(scope, opts \\ []) do
    limit = Keyword.get(opts, :limit, @default_limit)
    cutoff_days = Keyword.get(opts, :cutoff_days, @cutoff_days)
    since_date = Date.add(Date.utc_today(), -cutoff_days)

    locations = Query.log_locations()
    location_map = Map.new(locations, &{&1.id, &1})

    rows = Query.firsts_in_range(scope, locations, since_date)

    if rows == [] do
      []
    else
      rows
      |> Query.preload_life_observations()
      |> build_entries(location_map)
      |> Enum.take(limit)
    end
  end

  # --- Private ---

  # Group raw rows into {date, [entry]} tuples, applying deduplication.
  defp build_entries(rows, location_map) do
    rows
    |> Enum.group_by(& &1.observ_date)
    |> Enum.sort_by(fn {date, _} -> date end, {:desc, Date})
    |> Enum.map(fn {date, date_rows} ->
      entries =
        date_rows
        |> group_by_species()
        |> Enum.flat_map(fn {_species_page_id, species_rows} ->
          build_species_entries(species_rows, location_map)
        end)
        |> merge_entries()

      {date, entries}
    end)
    |> Enum.reject(fn {_date, entries} -> entries == [] end)
  end

  # Returns all candidate (area, type, life_observation) tuples for a species on a date,
  # then deduplicates by ancestry.
  defp build_species_entries(rows, location_map) do
    candidates =
      Enum.map(rows, fn row ->
        area = if row.location_id_scope, do: location_map[row.location_id_scope], else: nil
        type = if row.year_scope, do: :year, else: :total
        {area, type, row.year_scope, row.life_observation, row.list_total}
      end)

    deduplicated = deduplicate(candidates)

    Enum.map(deduplicated, fn {area, type, year, life_obs, list_total} ->
      %Entry{
        type: type,
        area: area,
        year: year,
        life_observations: [life_obs],
        list_total: list_total
      }
    end)
  end

  # Remove candidates that are "covered" by a more significant candidate.
  # Significance: total > year; shallower ancestry (world > country > subdivision).
  defp deduplicate(candidates) do
    total_area_ids =
      candidates
      |> Enum.filter(fn {_area, type, _year, _obs, _total} -> type == :total end)
      |> Enum.map(fn {area, _type, _year, _obs, _total} -> area_id(area) end)
      |> MapSet.new()

    year_area_ids =
      candidates
      |> Enum.filter(fn {_area, type, _year, _obs, _total} -> type == :year end)
      |> Enum.map(fn {area, _type, year, _obs, _total} -> {area_id(area), year} end)
      |> MapSet.new()

    Enum.reject(candidates, fn {area, type, year, _obs, _total} ->
      covered?(area, type, year, total_area_ids, year_area_ids)
    end)
  end

  # An entry is covered if the same area or any ancestor area has a
  # same-or-higher priority entry.
  # - A :total entry is covered if an ancestor has a :total.
  # - A :year entry is covered if self or ancestor has a :total,
  #   OR a strict ancestor has a :year for the same year.
  # "World" (nil area) has no ancestors. A world :year is covered if
  # world :total exists.
  defp covered?(area, type, year, total_area_ids, year_area_ids) do
    self_id = area_id(area)
    ancestor_ids = full_ancestor_chain(area)
    ids_to_check = [self_id | ancestor_ids]

    case type do
      :total ->
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

  # Merge entries with the same (type, area, year) into a single entry with
  # multiple life_observations. This handles the case where multiple species
  # are new to the same area on the same date.
  defp merge_entries(entries) do
    entries
    |> Enum.group_by(fn e -> {e.type, area_id(e.area), e.year} end)
    |> Enum.map(fn {{type, _area_id, year}, group} ->
      area = hd(group).area
      life_obs = Enum.flat_map(group, & &1.life_observations)
      list_total = group |> Enum.map(& &1.list_total) |> Enum.max()

      %Entry{
        type: type,
        area: area,
        year: year,
        life_observations: life_obs,
        list_total: list_total
      }
    end)
    |> Enum.sort_by(&entry_sort_key/1)
  end

  # Sort entries: total before year, world before country before subdivision.
  defp entry_sort_key(%Entry{type: type, area: area, year: year}) do
    type_order = if type == :total, do: 0, else: 1
    depth = if area, do: length(area.ancestry), else: 0
    {type_order, depth, year}
  end
end
