# Location Hierarchy Redesign

## Goal

Replace the current arbitrary-depth `ancestry` array (plus ad-hoc `cached_*`
columns) with a **fixed set of named hierarchy levels**, each stored as its own
foreign-key column on `locations`. This makes full-name generation deterministic
and makes region filtering (lifelist, search) a simple indexed `WHERE` instead
of array containment against `ancestry`.

The levels, top to bottom:

`country` → `subdivision1` → `subdivision2` → `city` → `site` → `section`

A location's level is its **`location_type`** (the existing column — "rank" and
"level" below both mean `location_type`). The six values above are the ordered
hierarchy.

**Special locations are out of scope but still exist.** `location_type` also has
a value `special`, which sits *outside* the ordered hierarchy — a special
location has no fixed level and can be assigned a parent of any rank. This
redesign **ignores `special`** (don't build its handling here); just don't break
it, and remember the type set is the six levels **plus** `special`.

## Requirements

- **Level FK columns.** Add `country_id`, `subdivision1_id`, `subdivision2_id`,
  `city_id`, `site_id` to `locations`, each a self-referential
  `belongs_to(... Location)`. There is **no `section_id`**: `section` is the
  lowest level and never an ancestor, so an FK at that level would always be
  null. These columns **are** the hierarchy — there is no separate tree edge and
  no arbitrary depth.
- **Levels are sparse / skippable.** Not every level must be filled. A location
  can be a child of `subdivision1` with `subdivision2`/`city` left null. A
  location's own level is its `location_type`; the FK columns point only to its
  ancestors (see slot-occupancy invariant below).
- **`country` and `subdivision1` are reference data.** They are imported from a
  file, shared across all users, and **not editable by users**. The lower levels
  (`city`, `site`, `section`) are user-created.
- **`parent_id` is conditional on the index page design (undecided).** It would
  be purely derived — the last non-null among
  `[country_id, subdivision1_id, … site_id]` — and carries no information the
  level FKs don't already have. It earns its keep **only** for a generic
  "children of unknown-level X" access pattern, i.e. a **tree-structured index
  page** ("expand a node to see its direct children"), where `where parent_id ==
  ^x` is far cleaner than branching on which level FK to match per node.
  - If the index page is **tree-structured**, add `parent_id` (a denormalized
    column kept in sync from the level FKs in the changeset).
  - If the index page is **level-specific / flat filtering** (e.g. list by
    `subdivision1`, drill via explicit level selects), skip it — it's dead
    weight, and adding it later is a one-column migration + one changeset line.
  - **Decide the index page structure first**, then this follows.
- **Locations index page (`my/locations/index.ex`) starts flat + search.** It is
  a hybrid today: a flat search mode (`Geo.search_locations` → `cached_*`
  preloads + `Location.long_name/1`) and a non-search `ancestry`-walking
  hierarchy view (`name_cache` + `location_breadcrumb`). Target the **flat
  search index first** — it falls out of the name (stage 4) + search/filtering
  (stage 5) work. The `ancestry`-based hierarchy/tree view is deferred and tied
  to the undecided index-page structure (and the `parent_id` decision): drop it
  or rebuild it on level FKs as a follow-on, not in the core redesign.
- **Integrity invariant — slot occupancy.** A location occupies exactly one
  `location_type` and may only carry FKs for levels **strictly above** its own:
  - Its own-level slot and every slot **below** it are `null` (a country has
    `subdivision1_id … section_id` null; a city has `site_id`/`section_id` null).
    Put plainly: a location cannot have an FK of its own level or below.
  - Every level **below `country`** must belong to a country — `country_id` is
    required for `subdivision1 … section` (only a top-level `country` may have it
    null). This is the real "every loc has a parent" rule: combined with
    prefix-consistency, having a country is what keeps a location from floating.
    Intermediate levels are still skippable (a city may hang directly off a
    `country` or a `subdivision1`, with `subdivision1`/`subdivision2` null).
  - Set ancestor slots are **prefix-consistent**: each ancestor's own
    higher-level FKs equal this location's (a `subdivision2` whose
    `subdivision1_id` differs from this location's is invalid). So a location's
    level FKs are a consistent subset of its ancestors' level FKs.
- **Integrity invariant — `location_type` change.** A location's
  `location_type` can only move within the band left open by its actual
  relatives:
  `(highest set parent level) < new level < (lowest existing child level)`.
  - **Parents (upper bound):** can promote to level L only if no parent slot at L
    or below is set. A city can become a `subdivision2` only if it has no
    `subdivision2` parent (nearest parent is `subdivision1` or higher).
  - **Children (lower bound):** can demote to level L only if no child is at L or
    below. A city can become a `site` only if it has no `site`-or-lower children.
  - `special` is exempt — it has no fixed level and these bounds don't apply.
- Enforce both in the changeset (and/or a DB constraint on the reference levels)
  so the chain can't drift. This risk exists regardless of the `parent_id`
  decision — it's introduced by splitting the path into independent columns.
- **Full-name generation** becomes a fixed preload + join over the level FKs
  (replacing `name_local_part` / `name_administrative_part` / `long_name` which
  currently read `cached_city` / `cached_subdivision` / `cached_country` /
  `cached_parent`). No more "which ancestors are cached" arbitrariness.
- **Card filtering by region** is `where: l.subdivision2_id == ^id` (etc.) with a
  btree index on each level FK. Card-side denormalization (copying region FKs
  onto `cards`) is **out of scope for now** — keep filtering by joining through
  the location; revisit only if join performance proves insufficient.

## Migration / removal

- Implement against a **clean database** — no backfill of existing `ancestry` /
  `cached_*` data is required.
- **Tests vs. column have opposite timing.** Drop the old `ancestry`/`cached_*`
  *tests* **early** (stage 2) so they don't run and fail while the new world is
  built — they've served their purpose as the model for the new level-FK tests.
  But **keep the `ancestry` column and its code working until the end** (final
  cleanup stage): `child_locations/1`, the special-locations join, and the
  lifelist region roll-up all still depend on `ancestry` until stage 5 rebuilds
  them on level FKs. Dropping the column early would leave the app actually
  broken (not just red tests) for several stages with no fallback.
  - Bonus: keeping `ancestry` populated alongside the new level FKs through
    stages 3–7 lets stage 5 optionally cross-check the new `child_locations`
    against the old array as a correctness sanity net.
- The `location_type` value set changes too: drop `continent` / `region` /
  `raion`, add `subdivision1` / `subdivision2` / `site` / `section`, keep
  `country` / `city` / `special`. Clean DB, so just update `@location_types` and
  the validation — no data remap.
- **Importing `country` / `subdivision1` reference data from a file is a later
  step** — out of scope here. Assume those rows exist; don't build the importer.
- **Leave `cached_public_location_id` in place for now**, but implement the
  redesign *as if it does not exist* — don't build new logic on it. Whether the
  new level FKs make it redundant (or whether it's still worth keeping to avoid
  too many preloads when resolving the nearest public ancestor) is a **later
  decision**. See `raw_public_location/1` and `set_public_location_changeset/1`.
- Dropped in the final cleanup stage (once nothing references them): `ancestry`
  column + virtual `parent_id` / `ancestors` fields, `put_ancestry`,
  `derive_admin_ids`, `put_cached_admin`, `ancestors/1`, `preload_ancestors/1`,
  `with_parent_id/1`, and the obsolete `cached_*` columns (`cached_country_id`,
  `cached_subdivision_id`, `cached_city_id`, `cached_parent_id`).
  `nearest_public_ancestor_id` / `cached_public_location_id` are the exception —
  left in place per above.

## Implementation stages

Implement in small, separately reviewable stages. **Failing tests between
stages are acceptable** when they belong to functionality a later stage
fixes/implements.

1. **Schema migration.** Add the five level FK columns (`country_id …
   site_id`; no `section_id`), their btree indexes, and the `belongs_to`
   associations; update
   the `location_type` value set (drop `continent`/`region`/`raion`, add
   `subdivision1`/`subdivision2`/`site`/`section`). Leave `ancestry` / `cached_*`
   in place so the app still compiles. Tests cover the columns and associations.
2. **Remove the old `ancestry` / `cached_*` tests.** Tests only — **the
   `ancestry` column and its code stay** (they're still load-bearing until
   stage 5). Delete the obsolete `ancestry`/`cached_*` test cases so they don't
   run and fail while the new world is built, and use them as the **model** for
   the new level-FK tests in stages 3–7. The old code keeps passing-but-unused.
3. **Slot-occupancy validation.** The single-row changeset invariant from
   *Integrity invariant — slot occupancy* (own-level-and-below null, no gap above
   a set slot, prefix-consistency). Pure validation, no write wiring yet —
   unit-test the changeset directly.
4. **Full-name generation over level FKs.** New preload + name builders
   replacing `name_local_part` / `name_administrative_part` / `long_name`'s
   reliance on `cached_*`. Reads only.
5. **Region filtering over level FKs.** Reads only. Rebuild the core primitive
   `Location.Query.child_locations/1` ("X plus all its descendants") on the level
   FKs: a descendant of X is any location whose slot for X's `location_type`
   equals `X.id` (e.g. descendants of a `subdivision1` X are
   `where: l.subdivision1_id == ^X.id`), plus X itself — so it dispatches on X's
   level to pick the column. Everything else rides on this:
   - card / lifelist / search filtering by region (the commented-out
     `cached_country_id` filters in `card/query.ex`, the lifelist region roll-up
     replacing `unnest(ancestry)` at `lifelist/query.ex:142`).
   - **Special locations** (otherwise out of scope, but they depend on the
     `ancestry`-based join). A special location is an amalgamation of member
     locations (`special_locations` join: `parent_location_id` → member
     `child_location_id`s); a card counts toward it if the card's location is a
     member **or a descendant** of one. Replace the `child_location_id in
     l.ancestry` test (`card/query.ex:43`, `lifelist/query.ex:151`) by fanning
     `child_locations/1` over the special's members and unioning the results — no
     new mechanism, it reuses the rebuilt primitive.
   - **Locations index page → flat + search.** Point `my/locations/index.ex`'s
     search mode at the rebuilt `search_locations` / `display_assocs` (now over
     level FKs). Replace the non-search `ancestry`-walking hierarchy view with the
     flat search list for now; the tree view is deferred (see requirements +
     index-page-structure open question). This stage is **read-only** — populate
     the index with fixtures for tests/review; full click-through (create a
     location, then see it here) only works once stage 6 lands the create UI.
6. **Create + simple update (no `location_type` change).** Wire the changeset to
   set level FKs from a chosen parent; handle create and edits that don't move
   `location_type`. Uses stage 3's validation.
7. **Update with `location_type` change.** Promote/demote within the band
   `(highest set parent level) < new level < (lowest existing child level)`, plus
   the **descendant FK cascade** — rewriting descendants' level FKs when a
   location's `location_type` moves.
8. **Final cleanup — drop `ancestry` and obsolete `cached_*`.** Now that nothing
   reads them, drop the `ancestry` column and the `cached_*` columns and delete
   the dead code (`put_ancestry`, `derive_admin_ids`, `put_cached_admin`,
   `ancestors/1`, `preload_ancestors/1`, `with_parent_id/1`, virtual
   `parent_id` / `ancestors`). Keep `cached_public_location_id` /
   `nearest_public_ancestor_id` per the decision above.

## Open questions (to adjust)

- Does any UI need the location's own level as an explicit column/field, rather
  than inferring it from the lowest non-null slot?
- Should the integrity invariant be a DB constraint, a changeset validation, or
  both?

## Process

- **Stage review gate.** Each stage is handed off for review when complete; the
  next stage and any commit wait for explicit per-stage approval. Don't batch
  stages or commit without an in-the-moment go-ahead.

## Decisions made during implementation

- **No `section_id` FK column.** `section` is the lowest hierarchy level and is
  never an ancestor, so a `section_id` FK would always be null. Level FK columns
  are the five above-lowest levels: `country_id`, `subdivision1_id`,
  `subdivision2_id`, `city_id`, `site_id`.
- **Index page = flat + search → no `parent_id` in the core redesign.** Per the
  `parent_id` requirement, the column is added only for a tree-structured index.
  The core redesign targets the flat search index (stage 5) and defers the tree
  view, so `parent_id` is **skipped**; adding it later is a one-column migration
  plus one changeset line.
- **`location_type` is an `Ecto.Enum`** (atoms in app code, strings in the DB),
  with the value set as its single source of truth — `validate_inclusion` is
  dropped (the type enforces membership). All `location_type` reads/matches use
  atoms (`:country`, `:special`, …); query comparisons pin atoms.

## Progress log

- **Stage 1 — done (pending review).** Migration
  `20260619120000_add_level_fks_to_locations.exs` adds the five level FK columns
  + btree indexes; schema gains the five `belongs_to` associations,
  `@hierarchy_levels` / `hierarchy_levels/0`, and the updated `@location_types`
  (`country subdivision1 subdivision2 city site section special`). `location_type`
  converted to `Ecto.Enum`; all readers updated to atoms (`geo`, `location/query`,
  `card/query`, legacy import, location_components, preferences, presenter,
  locations form). `ancestry` / `cached_*` left intact. New tests cover the
  columns/associations and the type accessors. Remaining red tests are all old
  `ancestry`/`cached_*`/dropped-type cases owned by stages 2/4/5/6.
- **Side fix (committed separately, `e0867f7f`).** Pre-existing registration test
  failures from the earlier `Remove :let={f}` commit (field ids changed
  `registration_form_*` → `user_*`); updated the test selectors. Unrelated to the
  redesign.
- **Stage 2 — done (committed `33589546`).** Removed the obsolete
  `ancestry`/`cached_*` unit tests from `location_test.exs` (cached-derivation
  changeset cases, the `full_name`/`name_local_part`/`name_administrative_part`/
  `long_name` name-builder describes, and the `ancestors`/`add_ancestors`/
  `preload_ancestors` describes); kept the required-field, type-accessor, level-FK,
  `Query.for_user`, `to_flag_emoji`, `raw_public_location`, and
  `set_public_location_changeset` tests. Remapped two trivial dropped-type fixtures
  in `geo_test.exs` (`region` → `subdivision1`; ownership loop to the new type set).
  The `ancestry`/`cached_*` columns and code stay intact. Remaining red tests
  (logbook roll-up, web form/show/index) are all later-stage-owned (4/5/6) and left
  red on purpose.
- **Stage 3 — done (pending review).** Added `Location.validate_slot_occupancy/1`,
  a pure single-row changeset validation for the three slot-occupancy invariants
  (own-level-and-below null; every non-country level belongs to a country, i.e.
  `country_id` required; ancestor prefix-consistency), with `@level_fks` /
  `level_fks/0` and the `@level_fk_by_level` map. `special` is exempt. Not wired
  into `changeset/2` (write wiring is stage 6) — it's standalone so tests call it
  directly. Note: prefix-consistency issues one `SELECT` for the referenced
  ancestors (the only non-single-row part). New `validate_slot_occupancy/1` describe
  in `location_test.exs` (10 cases). Suite unchanged at 7 red (the stage-5
  `logbook_test` roll-up cases); no new regressions.
  - **Refinement during review.** The original "no gap above a set slot"
    contiguity rule was reframed: it was largely redundant with
    prefix-consistency, and its real intent is "every location below `country`
    belongs to a country." Replaced with an explicit `country_id`-required check
    (`country` itself and `special` exempt), which is clearer and also catches an
    all-null floating location that the contiguity rule missed.
- **Stage 4 — done (pending review).** Full-name generation over the level FKs,
  reads only. Added `Location.long_name_from_levels/1` — own `name_en` plus each
  set ancestor's name from most-specific (`site`) up to `country`, skipping unset
  levels — backed by `@name_assocs` and a private `level_ancestors/1` that
  tolerates unloaded/nil assocs. Added `Location.Query.level_assocs/0` and
  `preload_levels/1` (mirroring `display_assocs`/`preload_display`) to attach the
  five level FK associations. The old `long_name`/`name_local_part`/
  `name_administrative_part` (and the `cached_*` preloads they read) are left
  intact and still wired to the call sites — swapping consumers over is deferred,
  and they're dropped in stage 8. `long_name_from_levels/1` describe in
  `location_test.exs`. Suite at 7 red (unchanged stage-5
  `logbook_test`/`geo_test` roll-up cases); no new regressions.
  - **Privacy refinement.** The name builder now drops private segments: it forms
    the chain `[self | ancestors]` and rejects any entry with `is_private` before
    joining names, so a private location's own name never surfaces and a private
    ancestor is omitted. This is a self-contained name fix (it does not resolve a
    public *location* for linking/identity — that's `raw_public_location`'s job,
    rebuilt over level FKs in stage 5). Added two cases: private leaf is dropped;
    a private mid-chain ancestor is dropped.
- **Stage 5 (query primitives) — done (pending review).** Region filtering over
  level FKs, reads only. **Scoped to the query layer**; the `my/locations`
  index/show page rebuild (flat search list, dropping the `ancestry` tree view) is
  split into a separate follow-up per the review-gate decision, so those
  expand/collapse/tree-view tests stay red on purpose alongside the stage-6 form
  tests.
  - **Core primitive.** Rebuilt `Location.Query.child_locations/1` on the level
    FKs: it dispatches on the location's own `location_type` to the matching
    descendant column (`@descendant_fk`: `country → country_id … site → site_id`)
    with `where field(l, fk) == id or l.id == id`; a `section` (no descendant
    column) or unmapped type matches only itself. Requires `location_type` in the
    passed map.
  - **Consumers.** `Geo.get_child_locations/1` now loads the parent and rides
    `child_locations/1` (excluding self). `Card.Query.by_location_with_descendants/1`
    special clause + `Lifelist.Query.location_ids_query/2` special parents now use
    a new `Location.Query.special_descendant_ids/1` — it loads the special's
    members and unions each member's `child_locations/1` (selecting ids). The
    lifelist `unnest(ancestry)` ancestor roll-up became a union of the five level
    FK columns of card locations.
  - **Logbook.** `Logbook.Query.scoped_query/1` replaced
    `scope_id = ANY(cl.ancestry)` with explicit `scope_id == cl.<level>_id` across
    the five FKs. `Logbook` ancestor-chain / depth ordering now use a new
    `Location.ancestor_ids/1` (the non-null level FK values, read straight off the
    columns — no preload) instead of `area.ancestry`.
  - **Tests.** New `child_locations/1`, `special_descendant_ids/1`, and
    `ancestor_ids/1` describes in `location_test.exs`; `geo_test`, `logbook_test`,
    `lifelist_test`, `card_search_test`, and `lifelist/index_test` fixtures
    migrated from `ancestry`/`cached_*` to level FKs. `GeoFixtures.location_fixture`
    cast whitelist gained the five level FK columns (they were silently dropped).
    Core `kjogvi` app suite green; remaining red tests are all stage-6
    (form/create-update) or the deferred index/show tree view.
- **Stage 5 (locations index page) — done (pending review).** Rebuilt
  `my/locations/index.ex` as a **flat search list** over level FKs, dropping the
  `ancestry`-walking tree view (recursive `render_location`, `expanded_locations`
  toggle state, `name_cache`, `location_breadcrumb`). The page is now: stats →
  search → full flat list (`Geo.list_locations/1`, scoped non-special locations
  ordered by name with `cards_count` + level assocs) → specials. Rows render with
  a `<ul>`/`<li>` structure and show the full long name as a subtitle.
  - **Name builder split (privacy).** The autocomplete and `/my` index are
    owner-facing — they must show the owner's own private location names. So the
    stage-4 builder split into two: `Location.long_name_from_levels/1` (plain, no
    privacy filtering — for owner contexts) and a new
    `public_long_name_from_levels/1` (drops private segments — for public display).
    The stage-4 privacy tests moved to the `public_*` describe.
  - **Search path → level FKs.** `Search.Location.search_locations` now preloads
    `level_assocs` (was `display_assocs`); its consumers swapped to the plain
    builder: the location autocomplete component and the card form's
    `location_display` / `fetch_card_for_edit` (now `preload_levels`).
  - **`children_count/1` → level FKs.** Rebuilt on `child_locations/1` (was the
    `ancestry @> [id]` fragment); powers the index/show delete guard. The flat
    list calls `can_delete_location?` per row (N+1, same as the prior search-result
    path) — acceptable for a personal list, revisit if it grows.
  - **Removed** `Geo.locations_by_parent/1` (only the tree view used it); replaced
    its test with a `list_locations/1` describe. Index/geo/card-form/search tests
    migrated to level FKs.
  - **Deferred to the show-page rebuild:** `my/locations/show.ex` still uses
    `Location.ancestors/1`, `Geo.direct_children/1`, and the old
    `Location.long_name/1` (breadcrumbs, ancestry chain, children, subtitle) — its
    two red tests and the stage-6 form tests are the only remaining failures.
- **Public-location resolution moved off `cached_public_location_id` (consumer
  rebuilt; column retirement set up for stage 8).** Surfaced by a real crash:
  with a fresh level-FK seed, private locations have `cached_public_location_id`
  nil (the seed/stage-6 path doesn't maintain the cache), so the lifelist's
  `preload_all_locations` blew up dereferencing the nil `cached_public_location`.
  - New `Location.public_location_from_levels/1`: the nearest non-private among
    `[self | level FK ancestors]` (mirrors `public_long_name_from_levels/1` but
    returns the location; `nil` only if self and all ancestors are private). Relies
    on the downward-closed-privacy assumption, same as the old `raw_public_location`.
  - `preload_all_locations` now preloads **level assocs** (not the `cached_*` chain)
    and resolves `public_location` via the new function, batch-preloading level
    assocs on the resolved public locations so their names build. The lifelist row
    component renders `long_name_from_levels/1` on the chosen `location_field`
    (replacing `name_local_part` / `name_administrative_part` / `cached_country`).
    `@minimal_select` gained the five level FK columns.
  - **Now unread by the live path:** `cached_public_location_id`,
    `set_public_location_changeset/1`, `nearest_public_ancestor_id/1`,
    `put_cached_public_location/1`, and the `cached_public_location` assoc. These
    are ready to drop in stage 8 — flipping the earlier "leave it in place" call
    now that level FKs make the cache redundant.
- **Stage 6 — done (pending review).** Create + simple update wired onto the
  level FKs (no `location_type` change yet); the show page rebuilt alongside.
  **Form UX = single parent picker** (per the decision): one Parent autocomplete
  whose selection derives all five level FKs; the per-level `cached_*`
  autocompletes are gone.
  - **Changeset.** `changeset/2` replaced `put_ancestry`/`put_cached_admin`/
    `put_cached_public_location` with `put_level_fks_from_parent/1` +
    `validate_slot_occupancy/1` (stage 3 now wired in). A cast `parent_id` drives
    it: a set id loads the parent and fills the FKs via the new
    `level_fks_from_parent/1` (parent's own FKs + the parent placed into its
    `location_type` slot; a `section`/`special`/nil-type parent contributes no
    slot); a nil id clears them; an absent id leaves existing FKs untouched (so a
    name-only edit doesn't disturb ancestry). `ancestry` is kept in sync from the
    parent's `ancestor_ids` for the legacy consumers still reading it.
    `@editable_fields` swapped `cached_parent_id`/`cached_city_id` for the five
    level FK columns. `validate_slot_occupancy/1` now also exempts a nil
    `location_type` (the factory default).
  - **Form LiveView.** Rebuilt on `parent_id`: select/clear a parent →
    re-derive + revalidate; edit mode reconstructs `parent_id` via the new
    `Location.parent_id_from_levels/1` (deepest set FK). Added a
    `#location-ancestry-summary` line and a `#location-ancestry-errors` list to
    surface slot-occupancy errors that don't map to a visible input (the level
    FKs are derived, not typed).
  - **Show page.** Off `cached_*`/`ancestry`: breadcrumbs + ancestry chain from
    `Geo.ancestor_locations/1` (level FKs), children from `Geo.direct_children/1`
    (rebuilt on a new `Location.Query.direct_children/1` — descendants whose
    deepest set FK is this location), subtitle from `long_name_from_levels/1`.
  - **Tests.** `form_test.exs` and the two red `show_test` cases rewritten to
    level FKs; new `changeset/2` derivation, `level_fks_from_parent/1`,
    `parent_id_from_levels/1`, `Query.direct_children/1`, `Geo.direct_children/1`,
    and `Geo.ancestor_locations/1` describes. The obsolete
    `create_location/2 cached_public_location_id derivation` describe in
    `geo_test.exs` (tested the now-removed cache write) was replaced with a level
    FK derivation describe; the ownership / owner-can-update fixtures gained a
    country parent to satisfy slot occupancy. Full suite green (536 core + 457
    web, 1 pre-existing skip).
