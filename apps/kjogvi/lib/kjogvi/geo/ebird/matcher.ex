defmodule Kjogvi.Geo.Ebird.Matcher do
  @moduledoc """
  Per-country matching passes linking eBird regions to common locations.

  Three passes, in order: link the country row to the common country with the
  same `iso_code`; link subdivision1 rows by `iso_code == subnational1_code`;
  then a name pass on the leftovers linking only unambiguous 1:1
  normalized-name matches. Ambiguous or unmatched rows are left for manual
  resolution.

  Idempotent and safe to re-run: an existing `location_id` is never
  overwritten (every update is guarded by `is_nil(location_id)`), and common
  locations already linked from another eBird row are never candidates.
  Operates on country and subdivision1 rows only — subdivision2 rows are
  linked by the sub2 import, never here.
  """

  alias Kjogvi.Geo.Ebird
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo
  alias Kjogvi.Util

  @doc """
  Runs the match passes for one eBird country. `opts` is reserved.

  Returns `%{code: n, name: n, left: n}` — rows linked by code (the country
  row included), rows linked by name, and the country's still-unlinked
  country/subdivision1 rows. An eBird-only country whose country row finds no
  common counterpart gets no subdivision passes: everything stays in `left`.
  """
  def match_country(country_code, _opts \\ []) do
    :telemetry.span([:kjogvi, :geo, :ebird, :match], %{country_code: country_code}, fn ->
      {:ok, summary} = Repo.transact(fn -> {:ok, run_passes(country_code)} end)
      {summary, Map.merge(%{result: :ok, country_code: country_code}, summary)}
    end)
  end

  @doc """
  The bulk code pass over every eBird country, run once after import: links all
  country rows to their common counterpart by code, then links subdivision1s
  only for the perfect-match (`:matched`) countries — those whose eBird and ISO
  subdivision1 code sets are identical (or that have none). A country with any
  code discrepancy has its subdivisions left entirely untouched, so it arrives
  at manual review whole. No name pass runs; that stays a per-country decision.

  Stricter than `match_country/2`'s subdivision code pass, which links any code
  match: here the all-or-nothing set check gates whether a country's
  subdivisions are touched at all.

  Returns `%{countries: n, subdivisions: n, matched: n}` — country rows linked,
  subdivision1 rows linked, and the number of `:matched`-shape countries whose
  subdivisions were eligible. Idempotent and safe to re-run.
  """
  def match_all do
    :telemetry.span([:kjogvi, :geo, :ebird, :match_all], %{}, fn ->
      {:ok, summary} = Repo.transact(fn -> {:ok, run_all_passes()} end)
      {summary, Map.merge(%{result: :ok}, summary)}
    end)
  end

  defp run_all_passes do
    matched_codes = Ebird.matched_country_codes()

    {countries_n, _} =
      EbirdLocation.Query.link_all_countries_by_iso() |> Repo.update_all([])

    {subdivisions_n, _} =
      matched_codes
      |> EbirdLocation.Query.link_subdivision1s_by_code_for_countries()
      |> Repo.update_all([])

    %{countries: countries_n, subdivisions: subdivisions_n, matched: length(matched_codes)}
  end

  defp run_passes(country_code) do
    country_n = country_pass(country_code)

    {code_n, name_n} =
      case anchor_country_id(country_code) do
        nil -> {0, 0}
        id -> {code_pass(country_code, id), name_pass(country_code, id)}
      end

    %{code: country_n + code_n, name: name_n, left: left_count(country_code)}
  end

  defp country_pass(country_code) do
    {n, _} =
      country_code
      |> EbirdLocation.Query.link_country_by_iso()
      |> Repo.update_all([])

    n
  end

  # The common country the eBird country row is linked to (by this run's
  # country pass, or earlier/manually) — the anchor for the subdivision passes.
  defp anchor_country_id(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> EbirdLocation.Query.countries()
    |> Repo.one()
    |> case do
      nil -> nil
      row -> row.location_id
    end
  end

  defp code_pass(country_code, common_country_id) do
    {n, _} =
      country_code
      |> EbirdLocation.Query.link_subdivision1s_by_code(common_country_id)
      |> Repo.update_all([])

    n
  end

  defp name_pass(country_code, common_country_id) do
    leftovers =
      EbirdLocation
      |> EbirdLocation.Query.for_country(country_code)
      |> EbirdLocation.Query.subdivision1s()
      |> EbirdLocation.Query.unmatched()
      |> Repo.all()

    case leftovers do
      [] ->
        0

      leftovers ->
        candidates =
          common_country_id
          |> EbirdLocation.Query.unlinked_common_subdivision1s()
          |> Repo.all()

        leftovers
        |> unambiguous_pairs(candidates)
        |> Enum.reduce(0, fn {ebird_id, location_id}, acc ->
          {n, _} =
            EbirdLocation
            |> EbirdLocation.Query.by_id(ebird_id)
            |> EbirdLocation.Query.unmatched()
            |> Repo.update_all(set: [location_id: location_id])

          acc + n
        end)
    end
  end

  # 1:1 matches only: the normalized name occurs exactly once among the
  # leftovers and exactly once among the candidates.
  defp unambiguous_pairs(leftovers, candidates) do
    ebird = Enum.group_by(leftovers, &Util.String.normalize_for_match(&1.name), & &1.id)
    common = Enum.group_by(candidates, &Util.String.normalize_for_match(&1.name_en), & &1.id)

    for {name, [ebird_id]} <- ebird,
        name != "",
        match?([_], Map.get(common, name, [])),
        do: {ebird_id, hd(common[name])}
  end

  defp left_count(country_code) do
    EbirdLocation
    |> EbirdLocation.Query.for_country(country_code)
    |> EbirdLocation.Query.matchable()
    |> EbirdLocation.Query.unmatched()
    |> Repo.aggregate(:count)
  end
end
