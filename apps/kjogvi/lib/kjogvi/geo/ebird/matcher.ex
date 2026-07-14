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

  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

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

  # Latin letters that NFD does *not* decompose into base + combining mark, so
  # the `\p{Mn}` strip leaves them intact. eBird tends to flatten these to their
  # base letter while ISO keeps them (e.g. Polish "Łódzkie" → eBird "Lodzkie"),
  # so folding them here lets the name pass match. Keyed on the downcased form.
  @special_letters %{
    "ł" => "l",
    "ø" => "o",
    "đ" => "d",
    "ð" => "d",
    "þ" => "th",
    "ß" => "ss",
    "ı" => "i",
    "æ" => "ae",
    "œ" => "oe",
    "ħ" => "h",
    "ŋ" => "n",
    "ĸ" => "k"
  }

  @doc """
  Normalizes a region name for the name pass: NFD-decompose and strip
  diacritics, downcase, fold non-decomposing Latin letters (ł, ø, ß, …) to
  their base form, and collapse punctuation/whitespace runs to single spaces.
  `nil` becomes `""` (which never matches).
  """
  def normalize_name(nil), do: ""

  def normalize_name(name) do
    name
    |> String.normalize(:nfd)
    |> String.replace(~r/\p{Mn}/u, "")
    |> String.downcase()
    |> fold_special_letters()
    |> String.replace(~r/[^\p{L}\p{N}]+/u, " ")
    |> String.trim()
  end

  defp fold_special_letters(string) do
    String.replace(string, Map.keys(@special_letters), &Map.fetch!(@special_letters, &1))
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
    ebird = Enum.group_by(leftovers, &normalize_name(&1.name), & &1.id)
    common = Enum.group_by(candidates, &normalize_name(&1.name_en), & &1.id)

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
