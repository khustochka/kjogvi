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
  Update query linking every unlinked eBird country row to the common country
  with `iso_code` equal to the eBird code — the bulk pass's country pass. Skips
  common locations already linked from another eBird row.
  """
  def link_all_countries_by_iso do
    from e in EbirdLocation,
      join: l in Location,
      on: l.iso_code == e.code and l.location_type == :country and is_nil(l.user_id),
      where: e.location_type == :country,
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
  Update query linking the unlinked eBird subdivision1 rows of the given
  countries to their common country's subdivision1s by
  `iso_code == subnational1_code` — the bulk pass's subdivision pass, run only
  for the perfect-match (`:matched`) countries. The common country is reached
  through the eBird country row's own link, so the country pass must have run
  first. Skips common locations already linked from another eBird row.
  """
  def link_subdivision1s_by_code_for_countries(country_codes) do
    from e in EbirdLocation,
      join: ec in EbirdLocation,
      on: ec.country_code == e.country_code and ec.location_type == :country,
      join: l in Location,
      on:
        l.iso_code == e.subnational1_code and l.location_type == :subdivision1 and
          is_nil(l.user_id) and l.country_id == ec.location_id,
      where: e.location_type == :subdivision1 and e.country_code in ^country_codes,
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
  The ISO side of one country's comparison: every common subdivision1 of the
  country the eBird `country_code` corresponds to, whatever its link state.

  The common country is reached by its own link when there is one, falling back
  to `iso_code == country_code` — so the ISO column is populated before the
  country row is linked (and keeps working for a manually linked eBird-only
  country, whose ISO code matches nothing).
  """
  def common_subdivision1s_for_country(country_code) do
    from l in Location,
      where: l.location_type == :subdivision1 and is_nil(l.user_id),
      where:
        l.country_id in subquery(
          from(c in Location,
            left_join: e in EbirdLocation,
            on: e.location_id == c.id and e.location_type == :country,
            where: c.location_type == :country and is_nil(c.user_id),
            where: e.code == ^country_code or c.iso_code == ^country_code,
            select: c.id
          )
        )
  end

  @doc """
  Narrows a *location* query to those no eBird row links — locations still free
  to be claimed. Complements `matched_location_ids/1`, which selects the taken
  ones.
  """
  def unclaimed(location_query) do
    from l in location_query, where: l.id not in subquery(matched_location_ids())
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
  Common subdivision1 rows as `{country_code, iso_code, name_en}` keyed by eBird
  `country_code` — the ISO side of the mismatch-shape comparison.

  The common country is reached by the eBird country row's own link, falling back
  to `iso_code == code`: the fallback covers countries the passes haven't linked
  yet, the link covers one whose ISO code matches nothing (a manually linked
  eBird-only country like Kosovo).
  """
  def common_sub1_codes_and_names_by_country(query \\ EbirdLocation) do
    from e in query,
      join: c in Location,
      on:
        (c.id == e.location_id or c.iso_code == e.code) and c.location_type == :country and
          is_nil(c.user_id),
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

    * `:matched` — nothing is left to link. Either the eBird and ISO subdivision1
      code sets are identical (a perfect match the bulk pass links with no
      leftovers — including a country with no subdivisions on either side), or
      eBird models the country as a single unit with no subdivisions at all
      (Monaco, Singapore, Greenland): once its country row is linked it is
      complete, and the ISO subdivisions it lacks are context, not a shortfall.
    * `:ebird_only` — the eBird country has no ISO counterpart at all;
      create-from-eBird.
    * `:ebird_only_subregions` — the mirror of the Monaco case: ISO treats the
      country as one unit while eBird subdivides it (Puerto Rico's 78 municipios,
      the Caymans, French Polynesia). No pass can help — there is nothing on the
      ISO side to match against — so every row needs create-from-eBird. Distinct
      from `:mixed`, where the two sides *do* both have subdivisions and merely
      disagree.
    * `:iso_extra` — every eBird subdivision1 code is among the ISO country's
      codes but ISO has more (a strict superset — subdivisions eBird doesn't
      cover); the code pass links every eBird row and leaves the ISO extras.
      Requires eBird to have *some* subdivisions: with none there is no pass to
      run, which is `:matched` above.
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
      stats.sub1_total == 0 -> :matched
      stats.iso_sub1_total == 0 -> :ebird_only_subregions
      stats.code_subset -> :iso_extra
      stats.name_set_match -> :name_candidate
      true -> :mixed
    end
  end
end
