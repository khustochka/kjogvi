defmodule Kjogvi.Legacy.Import.Locations do
  @moduledoc """
  Imports legacy `loci` rows into `Kjogvi.Geo.Location`, preserving every legacy
  id so checklists (which reference locations by their legacy id) keep resolving.

  The whole set arrives in one call (see `Kjogvi.Legacy.Import.perform_import/2`),
  which is required: a location's place in the hierarchy comes from its legacy
  `ancestry` (a top-to-bottom list of ancestor ids), and resolving it needs every
  ancestor's type in hand at once.

  ## Countries and subdivisions are upserted onto the ISO rows

  `country` and `subdivision1` are reference data already present from the ISO
  3166 import (`Kjogvi.Geo.Import`), keyed by `iso_code`. Rather than insert
  duplicates, each such legacy row is matched to its ISO row by ISO code and that
  row is renumbered to the legacy id (and given the legacy `slug`/`lat`/`lon`).
  This both avoids duplicates and makes the imported ids line up with the legacy
  ones the way the upper id range (`>= 10_000`) was reserved for.

  Matching:

    * a `country` matches on its legacy `iso_code` (alpha-2, e.g. `US`);
    * a `subdivision1` carries only the subdivision part in legacy data (e.g.
      `TX`); the full ISO 3166-2 code (`US-TX`) is built from its country
      ancestor's `iso_code`, then matched.

  A country/subdivision1 with no `iso_code`, or whose code has no matching ISO
  row, fails the import — these are reference data and must already exist.

  ## Specials inside the hierarchy

  A `special` sits outside the ordered hierarchy. When one appears in an ancestry
  chain it is created as a `special` location that still carries its **own**
  ancestor level FKs (so it places correctly in display/roll-up), but is
  **skipped** when deriving *descendants'* level FKs, so a descendant's FKs jump
  over it. Its direct ancestry children (rows whose deepest ancestor is the
  special) are linked as its `special_child_locations`.

  ## The `5mr` amalgamation

  A couple of specials are flag/slug-based rather than ancestry-based, restored
  from the original importer: they are forced to `special` by slug, and their
  members come from data flags rather than ancestry — every `five_mile_radius`
  row belongs to `5mr`.

  ## Ownership

  `country`/`subdivision1` stay common (they live on the ISO rows, `nil` owner);
  every other location — including untyped ones — is owned by the importing user.
  """

  import Ecto.Query

  alias Kjogvi.Geo.Location
  alias Kjogvi.Legacy.Import.Utils
  alias Kjogvi.Repo

  # Types upserted onto pre-existing ISO rows rather than inserted.
  @iso_types ~w(country subdivision1)a

  # Maps each ancestor's own level to the descendant FK column it fills.
  @level_fk_by_type %{
    country: :country_id,
    subdivision1: :subdivision1_id,
    subdivision2: :subdivision2_id,
    city: :city_id,
    site: :site_id
  }

  def import(columns_str, rows, opts) do
    columns = Enum.map(columns_str, &String.to_atom/1)
    user_id = opts[:user].id

    locs =
      rows
      |> Enum.map(&(columns |> Enum.zip(&1) |> Map.new() |> normalize()))
      |> index_by_id()

    # Renumbering ISO rows in place transiently dangles the level FKs of rows that
    # reference their old ids; defer the FK checks to commit so the renumber and
    # the child re-pointing can happen in any order within this transaction.
    Repo.query!("SET CONSTRAINTS ALL DEFERRED")

    upsert_iso_locations(locs)
    insert_hierarchy_locations(locs, user_id)
    insert_special_locations(locs, user_id)
    link_special_children(locs)
    bump_id_sequence()

    :ok
  end

  def cleanup do
    Repo.query("DELETE FROM locations WHERE import_source='legacy';")
  end

  # Imported locations start at this id, reserving the lower range for hand-managed
  # rows; the ISO import reserves the same range, so the legacy ids the upsert
  # writes onto the ISO rows stay above it.
  @min_start_seq 10_000

  defp bump_id_sequence do
    Repo.query!(
      "SELECT setval('locations_id_seq', GREATEST($1, (SELECT COALESCE(MAX(id), 0) FROM locations)))",
      [@min_start_seq]
    )
  end

  # One normalized struct-ish map per legacy row, carrying just what the import
  # needs. `ancestry` is the top-to-bottom list of ancestor ids.
  defp normalize(row) do
    %{
      id: row.id,
      slug: row.slug,
      name_en: row.name_en,
      location_type: to_type(row),
      iso_code: Utils.blank_to_nil(row.iso_code),
      is_private: row.private_loc || false,
      lat: to_decimal(row.lat),
      lon: to_decimal(row.lon),
      public_index: row.public_index,
      is_5mr: row.five_mile_radius || false,
      ancestry: parse_ancestry(row.ancestry)
    }
  end

  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)

  # The two flag/slug-based specials (see the `5mr` / `arabat_spit` linkers).
  @amalgamation_special_slugs ~w(5mr arabat_spit)

  # `location_type` is required (NOT NULL) and comes from the curated `loc_type`
  # column, so a blank one is a data error to fail on, not a nil to insert. The
  # `5mr`/`arabat_spit` amalgamations are forced `special` by slug, as in the
  # original importer.
  defp to_type(%{slug: slug}) when slug in @amalgamation_special_slugs, do: :special

  defp to_type(%{loc_type: value, slug: slug}) do
    case Utils.blank_to_nil(value) do
      nil -> raise "Legacy location #{inspect(slug)} has no loc_type."
      str -> String.to_existing_atom(str)
    end
  end

  defp parse_ancestry(nil), do: []
  defp parse_ancestry(""), do: []

  defp parse_ancestry(str) do
    str |> String.split("/") |> Enum.map(&String.to_integer/1)
  end

  defp index_by_id(locs) do
    Map.new(locs, &{&1.id, &1})
  end

  # Renumber each ISO reference row to its legacy id (and copy legacy
  # slug/lat/lon), so descendants' level FKs and checklists point at the legacy ids.
  # The ISO row's own `country_id` is re-derived from ancestry too: a subdivision
  # renumbered to a legacy id would otherwise still point at the now-renumbered
  # ISO country's old id.
  #
  # Countries are renumbered before subdivisions: a subdivision's new `country_id`
  # is its country's legacy id, which must already exist (FK) when the subdivision
  # is updated.
  defp upsert_iso_locations(locs) do
    locs
    |> Map.values()
    |> Enum.filter(&(&1.location_type in @iso_types))
    |> Enum.sort_by(&iso_upsert_order(&1.location_type))
    |> Enum.each(&upsert_iso_location(&1, locs))
  end

  defp iso_upsert_order(:country), do: 0
  defp iso_upsert_order(:subdivision1), do: 1

  defp upsert_iso_location(loc, locs) do
    iso_code = full_iso_code(loc, locs)
    existing = Repo.get_by(Location, iso_code: iso_code)

    unless existing do
      raise "Legacy #{loc.location_type} #{inspect(loc.slug)} has no matching ISO row for #{inspect(iso_code)}."
    end

    changes =
      %{id: loc.id, slug: loc.slug, lat: loc.lat, lon: loc.lon}
      |> Map.merge(level_fks(loc, locs))

    existing
    |> Ecto.Changeset.change(changes)
    |> Repo.update!()

    repoint_children(existing.id, loc)
  end

  # When an ISO row is renumbered to its legacy id, every other location that
  # referenced it through the level FK for its own level (e.g. the ISO
  # subdivisions of a country that aren't in the legacy data) is repointed to the
  # new id, so no FK dangles at commit. The deferred constraints make this safe.
  defp repoint_children(old_id, %{id: new_id, location_type: type}) do
    fk = Map.fetch!(@level_fk_by_type, type)

    from(l in Location, where: field(l, ^fk) == ^old_id)
    |> Repo.update_all(set: [{fk, new_id}])
  end

  # A country matches on its own alpha-2 code; a subdivision matches on the full
  # ISO 3166-2 code built from its country ancestor (legacy data holds only the
  # subdivision part, e.g. `TX` -> `US-TX`).
  defp full_iso_code(%{location_type: :country} = loc, _locs), do: require_iso!(loc)

  defp full_iso_code(%{location_type: :subdivision1} = loc, locs) do
    country = country_ancestor(loc, locs)
    "#{require_iso!(country)}-#{require_iso!(loc)}"
  end

  defp require_iso!(%{iso_code: nil, slug: slug, location_type: type}) do
    raise "Legacy #{type} #{inspect(slug)} has no iso_code; cannot match an ISO row."
  end

  defp require_iso!(%{iso_code: iso_code}), do: iso_code

  defp country_ancestor(loc, locs) do
    ancestor =
      Enum.find_value(loc.ancestry, fn id ->
        case locs[id] do
          %{location_type: :country} = country -> country
          _ -> nil
        end
      end)

    ancestor ||
      raise "Legacy subdivision1 #{inspect(loc.slug)} has no country ancestor in its ancestry."
  end

  # Insert every ordered-hierarchy location below subdivision1 (subdivision2 down
  # to section, plus untyped rows), with level FKs derived from ancestry.
  defp insert_hierarchy_locations(locs, user_id) do
    rows =
      for {_id, loc} <- locs,
          loc.location_type not in @iso_types,
          loc.location_type != :special do
        base_row(loc, user_id) |> Map.merge(level_fks(loc, locs))
      end

    Repo.insert_all(Location, rows)
  end

  # A special carries its own ancestor level FKs too (derived from its ancestry,
  # skipping any special ancestors), so its display name and region roll-up place
  # it correctly even though it sits outside the ordered hierarchy.
  defp insert_special_locations(locs, user_id) do
    rows =
      for {_id, loc} <- locs, loc.location_type == :special do
        base_row(loc, user_id) |> Map.merge(level_fks(loc, locs))
      end

    Repo.insert_all(Location, rows)
  end

  # Derives the level FK columns from ancestry: each ancestor's own type picks the
  # FK column it fills. `special` ancestors are outside the hierarchy and skipped.
  defp level_fks(loc, locs) do
    for ancestor_id <- loc.ancestry,
        ancestor = ancestor!(loc, ancestor_id, locs),
        fk = @level_fk_by_type[ancestor.location_type],
        not is_nil(fk),
        into: %{} do
      {fk, ancestor_id}
    end
  end

  defp ancestor!(loc, ancestor_id, locs) do
    locs[ancestor_id] ||
      raise "Legacy location #{inspect(loc.slug)} references unknown ancestor id #{ancestor_id}."
  end

  # Links every special to its `special_child_locations` in one pass. A special's
  # members come from two sources, unioned:
  #
  #   * ancestry — rows whose deepest ancestor is the special (specials sitting
  #     inside the hierarchy);
  #   * the flag/slug-based amalgamations — restored from the original importer:
  #     every `five_mile_radius` row belongs to `5mr` (see `amalgamation_member_ids/1`).
  defp link_special_children(locs) do
    children_by_special =
      locs
      |> ancestry_children_by_special()
      |> merge_member_ids(amalgamation_member_ids(locs))

    for {_id, loc} <- locs, loc.location_type == :special do
      child_ids = Map.get(children_by_special, loc.id, [])
      children = Repo.all(from l in Location, where: l.id in ^child_ids)

      Repo.get!(Location, loc.id)
      |> Repo.preload(:special_child_locations)
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.put_assoc(:special_child_locations, children)
      |> Repo.update!()
    end
  end

  defp ancestry_children_by_special(locs) do
    Enum.reduce(locs, %{}, fn {_id, loc}, acc ->
      case List.last(loc.ancestry) do
        nil -> acc
        parent_id -> Map.update(acc, parent_id, [loc.id], &[loc.id | &1])
      end
    end)
  end

  # Member ids for the flag/slug-based amalgamations, keyed by the special's own
  # id: `5mr` gets every `five_mile_radius` row. Absent specials (slug not in the
  # data) contribute nothing.
  @arabat_member_slugs ~w(arabatska_khersonska arabatska_krym)

  defp amalgamation_member_ids(locs) do
    by_slug = Map.new(Map.values(locs), &{&1.slug, &1.id})

    %{}
    |> put_member_ids(by_slug["5mr"], for({_, l} <- locs, l.is_5mr, do: l.id))
    |> put_member_ids(by_slug["arabat_spit"], member_ids_by_slug(locs, @arabat_member_slugs))
  end

  defp member_ids_by_slug(locs, slugs) do
    for {_id, loc} <- locs, loc.slug in slugs, do: loc.id
  end

  defp put_member_ids(acc, nil, _ids), do: acc
  defp put_member_ids(acc, special_id, ids), do: Map.put(acc, special_id, ids)

  defp merge_member_ids(a, b) do
    Map.merge(a, b, fn _special_id, ids_a, ids_b -> Enum.uniq(ids_a ++ ids_b) end)
  end

  # The geographic backbone (country/subdivision1) lives on common ISO rows;
  # everything else, including untyped personal locations, is owned by the user.
  defp owner(:country), do: nil
  defp owner(:subdivision1), do: nil
  defp owner(_type), do: :user

  # `base_row` builds only inserted rows — hierarchy locations and specials, never
  # the upserted ISO types — so `iso_code` is left null: it is reserved for the
  # common ISO rows (and is under a unique index), so a stray legacy value on a
  # user location would be meaningless and could collide.
  defp base_row(loc, user_id) do
    now = DateTime.utc_now()

    %{
      id: loc.id,
      slug: loc.slug,
      name_en: loc.name_en,
      location_type: loc.location_type,
      is_private: loc.is_private,
      lat: loc.lat,
      lon: loc.lon,
      public_index: loc.public_index,
      user_id: if(owner(loc.location_type) == :user, do: user_id),
      import_source: :legacy,
      inserted_at: now,
      updated_at: now
    }
  end
end
