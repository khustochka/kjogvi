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

  @doc """
  Rows linked to the given common location.
  """
  def for_location(query \\ EbirdLocation, location_id) do
    from e in query, where: e.location_id == ^location_id
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
  eBird country codes that have a matching ISO common country (by
  `iso_code == code`) — whether an unlinked eBird country has an ISO counterpart
  at all, separating the `:ebird_only` shape from the linkable ones.
  """
  def country_codes_with_iso_match(query \\ EbirdLocation) do
    from e in query,
      join: c in Location,
      on: c.iso_code == e.code and c.location_type == :country and is_nil(c.user_id),
      where: e.location_type == :country,
      select: e.country_code
  end

  @doc """
  All eBird subdivision1 rows as `{country_code, subnational1_code, name}` — the
  eBird side of the mismatch-shape comparison (code-subset and name-set).
  Compared over the full set, not by link state: a country is linked
  all-or-nothing, so its shape is a property of the sets themselves.
  """
  def sub1_codes_and_names(query \\ EbirdLocation) do
    from e in query,
      where: e.location_type == :subdivision1,
      select: {e.country_code, e.subnational1_code, e.name}
  end

  @doc """
  Common subdivision1 rows as `{country_code, iso_code, name_en}`, keyed by the
  eBird `country_code` of the country whose ISO code matches — the ISO side of
  the mismatch-shape comparison. Reaches the common country by `iso_code`, not by
  link, so it works for still-unlinked countries.
  """
  def common_sub1_codes_and_names_by_country(query \\ EbirdLocation) do
    from e in query,
      join: c in Location,
      on: c.iso_code == e.code and c.location_type == :country and is_nil(c.user_id),
      join: s in Location,
      on: s.country_id == c.id and s.location_type == :subdivision1 and is_nil(s.user_id),
      where: e.location_type == :country,
      select: {e.country_code, s.iso_code, s.name_en}
  end

  @doc """
  Derives a country's match *shape* from its merged stats (see
  `Kjogvi.Geo.Ebird.country_statuses/0`).

  The status is purely the shape of how the eBird and ISO subdivision1 sets line
  up — independent of link progress, which is a separate axis (the "not fully
  linked" work queue). Because a country is the atomic triage unit — its rows are
  linked all-or-nothing — the shape is a property of the full eBird-vs-ISO sets,
  computed regardless of link state. A half-linked country therefore still reads
  as its shape (e.g. `:matched`) and simply shows up under "not fully linked".

  The `has_iso_country` gate separates `:ebird_only` from the shapes that compare
  subdivision sets:

    * `:matched` — the eBird and ISO subdivision1 code sets are identical (a
      perfect match, linked by the bulk pass with no leftovers — including a
      country with no subdivisions on either side).
    * `:ebird_only` — the eBird country has no ISO counterpart at all;
      create-from-eBird.
    * `:iso_extra` — every eBird subdivision1 code is among the ISO country's
      codes but ISO has more (a strict superset — subdivisions eBird doesn't
      cover); the code pass links every eBird row and leaves the ISO extras.
    * `:name_candidate` — the eBird and ISO subdivision1 *name* sets are equal
      though codes differ (the Poland case); the name pass links them.
    * `:mixed` — eBird and ISO subdivisions overlap only partially, neither by
      code nor by whole-name set (junk pseudo-regions, word-order name
      differences); resolved by hand in the workbench.

  The code and name shapes are mutually exclusive (a name candidate matches by
  name *but not* by code), so the order among them is defensive, not a tiebreak.
  """
  def derive_status(stats) do
    cond do
      not stats.has_iso_country -> :ebird_only
      stats.code_set_equal -> :matched
      stats.code_subset -> :iso_extra
      stats.name_set_match -> :name_candidate
      true -> :mixed
    end
  end
end
