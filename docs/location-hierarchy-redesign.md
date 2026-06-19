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
  levels — backed by `@name_assocs` and a private `level_ancestor_names/1` that
  tolerates unloaded/nil assocs. Added `Location.Query.level_assocs/0` and
  `preload_levels/1` (mirroring `display_assocs`/`preload_display`) to attach the
  five level FK associations. The old `long_name`/`name_local_part`/
  `name_administrative_part` (and the `cached_*` preloads they read) are left
  intact and still wired to the call sites — swapping consumers over is deferred,
  and they're dropped in stage 8. New `long_name_from_levels/1` describe in
  `location_test.exs` (3 cases: full chain, skipped intermediate level, bare
  country). Suite at 7 red (unchanged stage-5 `logbook_test`/`geo_test` roll-up
  cases); no new regressions.
