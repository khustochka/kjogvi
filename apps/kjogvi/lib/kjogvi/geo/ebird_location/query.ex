defmodule Kjogvi.Geo.EbirdLocation.Query do
  @moduledoc """
  Queries for eBird locations, including the matching passes' link updates and
  the per-country match status aggregation.
  """

  import Ecto.Query

  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location

  def order_by_code(query \\ EbirdLocation) do
    from e in query, order_by: e.code
  end

  def for_country(query \\ EbirdLocation, country_code) do
    from e in query, where: e.country_code == ^country_code
  end

  def by_id(query \\ EbirdLocation, id) do
    from e in query, where: e.id == ^id
  end

  def countries(query \\ EbirdLocation) do
    from e in query, where: e.location_type == :country
  end

  def subdivision1s(query \\ EbirdLocation) do
    from e in query, where: e.location_type == :subdivision1
  end

  @doc """
  Country and subdivision1 rows — what matching and the derived statuses
  operate on. Subdivision2 rows belong to the sub2 import.
  """
  def matchable(query \\ EbirdLocation) do
    from e in query, where: e.location_type in [:country, :subdivision1]
  end

  @doc """
  Preloads the linked location with its level associations, for display names.
  """
  def preload_location(query \\ EbirdLocation) do
    preload(query, location: ^Location.Query.level_assocs())
  end

  @doc """
  Rows linked to a common location.
  """
  def matched(query \\ EbirdLocation) do
    from e in query, where: not is_nil(e.location_id)
  end

  def unmatched(query \\ EbirdLocation) do
    from e in query, where: is_nil(e.location_id)
  end

  @doc """
  Common location ids already taken by some eBird row — for `not in subquery`
  guards keeping the matcher off locations linked elsewhere.
  """
  def matched_location_ids(query \\ EbirdLocation) do
    query |> matched() |> select([e], e.location_id)
  end

  @doc """
  Per-type totals with the matched (linked) count:
  `{location_type, total, matched}` rows.
  """
  def count_by_type_with_matched(query \\ EbirdLocation) do
    from e in query,
      group_by: e.location_type,
      select: {e.location_type, count(e.id), count(e.location_id)}
  end

  @doc """
  Update query linking the country's unlinked eBird country row to the common
  country with `iso_code` equal to the eBird code. Skips common locations
  already linked from another eBird row.
  """
  def link_country_by_iso(country_code) do
    from e in EbirdLocation,
      join: l in Location,
      on: l.iso_code == e.code and l.location_type == :country and is_nil(l.user_id),
      where: e.location_type == :country and e.code == ^country_code,
      where: is_nil(e.location_id),
      where: l.id not in subquery(matched_location_ids()),
      update: [set: [location_id: l.id]]
  end

  @doc """
  Update query linking the country's unlinked eBird subdivision1 rows to the
  given common country's subdivision1s by `iso_code == subnational1_code`.
  Skips common locations already linked from another eBird row.
  """
  def link_subdivision1s_by_code(country_code, common_country_id) do
    from e in EbirdLocation,
      join: l in Location,
      on:
        l.iso_code == e.subnational1_code and l.location_type == :subdivision1 and
          is_nil(l.user_id) and l.country_id == ^common_country_id,
      where: e.country_code == ^country_code and e.location_type == :subdivision1,
      where: is_nil(e.location_id),
      where: l.id not in subquery(matched_location_ids()),
      update: [set: [location_id: l.id]]
  end

  @doc """
  The given common country's subdivision1s not linked from any eBird row —
  the name pass's candidates.
  """
  def unlinked_common_subdivision1s(common_country_id) do
    from l in Location,
      where:
        l.location_type == :subdivision1 and is_nil(l.user_id) and
          l.country_id == ^common_country_id,
      where: l.id not in subquery(matched_location_ids())
  end

  @doc """
  One row per eBird country row: `country_code`, whether it is linked, and
  whether the link is code-consistent (linked location's `iso_code` equals the
  eBird code).
  """
  def country_match_stats(query \\ EbirdLocation) do
    from e in query,
      left_join: l in assoc(e, :location),
      where: e.location_type == :country,
      select: %{
        country_code: e.country_code,
        country_linked: not is_nil(e.location_id),
        country_code_match: coalesce(l.iso_code == e.code, false)
      }
  end

  @doc """
  Subdivision1 totals per country: linked count and code-consistent count
  (linked location's `iso_code` equals `subnational1_code`).
  """
  def sub1_match_stats(query \\ EbirdLocation) do
    from e in query,
      left_join: l in assoc(e, :location),
      where: e.location_type == :subdivision1,
      group_by: e.country_code,
      select: %{
        country_code: e.country_code,
        sub1_total: count(e.id),
        sub1_linked: count(e.location_id),
        sub1_code_matched: filter(count(e.id), l.iso_code == e.subnational1_code)
      }
  end

  @doc """
  Per linked eBird country: how many subdivision1s its linked common country
  has, and how many of those no eBird row points at (`iso_extra` — ISO-only
  subdivisions, the Hungary case). Anchored on the link, not the code, so
  manually linked eBird-only countries work too.
  """
  def iso_sub1_stats(query \\ EbirdLocation) do
    from e in query,
      join: c in assoc(e, :location),
      join: s in Location,
      on: s.country_id == c.id and s.location_type == :subdivision1 and is_nil(s.user_id),
      left_join: m in EbirdLocation,
      on: m.location_id == s.id,
      where: e.location_type == :country,
      group_by: e.country_code,
      select: %{
        country_code: e.country_code,
        iso_sub1_total: count(s.id),
        iso_extra: filter(count(s.id), is_nil(m.id))
      }
  end

  @doc """
  Derives a country's match status from its merged stats (see
  `Kjogvi.Geo.Ebird.country_statuses/0`), per the §5.1 table: `:matched`
  (everything linked code-consistently, eBird and ISO sets equal),
  `:matched_iso_extra` (all eBird rows linked but ISO has extra subdivisions),
  `:matched_mixed` (all linked, some links not by code), `:partial`,
  `:unmatched`. When both apply, `:matched_iso_extra` outranks
  `:matched_mixed`.
  """
  def derive_status(stats) do
    cond do
      not stats.country_linked and stats.sub1_linked == 0 ->
        :unmatched

      not stats.country_linked or stats.sub1_linked < stats.sub1_total ->
        :partial

      stats.iso_extra > 0 ->
        :matched_iso_extra

      not stats.country_code_match or stats.sub1_code_matched < stats.sub1_linked ->
        :matched_mixed

      true ->
        :matched
    end
  end
end
