# Common Locations & eBird Regions: Data Management Plan

Status: draft for review · Branch: `ebird-locations-map` · 2026-07-01

## 1. Goal

Turn the common locations (`locations` with `user_id IS NULL`) and the eBird
region reference (`ebird_locations`) into **curated datasets**: seeded once from
their raw sources (ISO 3166, eBird's region dump), then gradually improved by
hand (matching, additions, subdivision2s), and snapshotted to S3 as CSV so any
environment can restore the curated state instead of redoing the work.

The working loop:

```
bootstrap (once, local):  ISO import ──► locations (common)
                          all_ebird_locs.json ──► ebird_locations

curate (repeatedly, admin UI):  match eBird ↔ common, import sub2s, hand-edits

snapshot:  dump both datasets ──► CSV on S3
restore:   CSV on S3 ──► any environment's DB (admin UI)
```

After the first dump, **the S3 CSVs are the canonical seed**; the raw ISO/eBird
imports become bootstrap-only tools. The ISO import card leaves `/my/imports`.

## 2. Datasets

### 2.1 Common locations (`locations`, `user_id IS NULL`)

- Today: countries + subdivision1s from `Kjogvi.Geo.Import` (ISO 3166 JSONL).
- Growing over time: subdivision2s imported from eBird (country by country),
  hand-created locations for eBird-only regions, name/coordinate fixes.
- Referenced by id from user locations (level FKs), checklists, and
  `ebird_locations.location_id` → **ids must be stable across environments**.
  The existing id reservation (`@min_start_seq 10_000`) already supports this.

### 2.2 eBird regions (`ebird_locations`)

- Reference copy of eBird's region tree (253 countries, ~3.6k sub1, ~4.7k sub2
  in the current dump), keyed by `code`. Schema exists on this branch.
- Carries the mapping to common locations (`location_id`, unique) — the whole
  match state (see §5).
- Nothing references `ebird_locations` by id, so `code` is the natural
  dump/restore key.

## 3. Schema changes

None needed initially — the branch's `ebird_locations` table already carries
everything. `location_id` alone is the match state:

- "Is matched" = `location_id` set.
- "Matched by code" is **derivable**, not stored: the eBird `code` equals the
  linked location's `iso_code`. Any other link (name-guessed, manual, created)
  is just "linked otherwise" — the distinction between *those* has no consumer,
  so no `match_type` provenance column for now. If a need appears later (e.g.
  selectively re-running an improved name pass), a nullable column is a cheap
  additive migration; only name-vs-manual history would be unrecoverable, and
  nothing planned depends on it.

One small addition rides along:

- Add `:iso` and `:ebird_regions` to `Kjogvi.Types.ImportSource`. The ISO
  import sets `import_source: :iso` (today ISO provenance hides in `extras`);
  common locations created from the eBird region tree (matcher "create" action,
  sub2 import) get `:ebird_regions`. The existing `:ebird` keeps its current
  meaning — personal locations from a user's eBird data import — and is never
  used for common locations.

No changes to `locations` structure otherwise. Common subdivision2s are already
legal: only *user-owned* locations are restricted from common-only types.

## 4. New modules

All query logic goes in `Query` submodules per convention.

| Module | Purpose |
|---|---|
| `Kjogvi.Geo.Ebird.Import` | One-time JSON → `ebird_locations` (bootstrap, run locally) |
| `Kjogvi.Geo.Ebird.Matcher` | Per-country matching passes (code, name) — §5 |
| `Kjogvi.Geo.Ebird.Sub2Import` | Per-country eBird sub2 → common subdivision2 locations — §6 |
| `Kjogvi.Geo.Dump` | Dump a dataset to CSV via the storage adapter — §7 |
| `Kjogvi.Geo.Restore` | Restore a dataset from CSV via the storage adapter — §7 |
| `Kjogvi.Datasets.LocalAdapter` / `.S3Adapter` | Universal dataset storage backends, not geo-specific (local default, S3 in prod) — §7.3 |
| `Kjogvi.Geo.EbirdLocation.Query` | Composable queries: by country, match status aggregation, unmatched rows… |

Context entry points on `Kjogvi.Geo` (or a `Kjogvi.Geo.Ebird` context if it gets
crowded). Telemetry events (`[:kjogvi, :geo, :dump]`, `[:kjogvi, :geo,
:restore]`, `[:kjogvi, :geo, :ebird, :match]`, …) for logging/observability,
following the ISO import's `:telemetry.span` pattern.

### 4.1 eBird JSON import (bootstrap)

`Kjogvi.Geo.Ebird.Import.from_json(path)`:

- Parse the map of `code => attrs`; derive `location_type` from which code
  fields are present (`subnational2Code` → `subdivision2`, `subnational1Code` →
  `subdivision1`, else `country`).
- Skip malformed pseudo-rows (e.g. the `"aba"` entry with no `countryCode`);
  log what was skipped.
- `Repo.insert_all` in chunks, upsert on `code` (re-runnable against a newer
  eBird dump; refreshes name fields, never touches `location_id`).
- Like the ISO import, the source JSON lives read-only in the datasets storage
  under `geo/sources/all_ebird_locs.json` (uploaded out-of-band; S3 in prod):
  `import/0` reads it from there for the admin imports card, `from_json/1`
  takes an explicit local path.

## 5. Matching eBird ↔ common locations

### 5.1 Row-level links, derived country status

Row-level truth: `location_id`. Country-level status is **derived, never
stored** — always truthful, survives dump/restore for free, no bookkeeping to
drift. "By code" falls out of comparing the eBird code with the linked
location's `iso_code` (§3).

Derived status per eBird country (one aggregate query over `ebird_locations`
grouped by `country_code`, joined against the ISO country's subdivision1s):

| Status | Meaning |
|---|---|
| `matched` | Country row + every sub1 row linked, eBird set == ISO set, all links code-consistent |
| `matched_mixed` | All linked, but some links are not code matches (name-guessed / manual / created) |
| `matched_iso_extra` | All eBird rows linked, ISO has subdivisions with no eBird counterpart (Hungary) — still fully ready |
| `partial` | Some sub1 rows linked, some not |
| `unmatched` | Nothing linked yet (incl. eBird-only pseudo-countries until handled) |

"Ready" (for lifelist/checklist purposes and for sub2 import) = every eBird row
of the country has `location_id`. The finer statuses exist so the admin UI can
show *how* a country got ready and what still needs eyes. Exact label names are
cosmetic and easy to change; the statuses above are ordered so the badge can
show the "worst" applicable one.

The known discrepancy classes this must tolerate (from the sampling):
countries only in eBird (AC, XK, XX, …), only in ISO (BQ, CW, SX — fine, they
just have no eBird counterpart), zero code overlap (CZ, PL, FR, …), and partial
overlap with a few odd codes on each side (AF, AZ, …).

### 5.2 Matcher passes (per country, idempotent)

`Matcher.match_country(country_code, opts)`:

1. **Country pass** — link the eBird country row to the common country with
   `iso_code == country_code`. eBird-only codes find nothing and stay
   unmatched (resolved manually, see 5.3).
2. **Code pass** — for each unlinked sub1 row, link to the common subdivision1
   (of that country) whose `iso_code` equals `subnational1Code`.
3. **Name pass** (only if leftovers remain; runs on the leftovers only) —
   normalize names on both sides (NFD, strip diacritics, downcase, collapse
   punctuation/whitespace) and link only **unambiguous 1:1** matches.
   Ambiguous or unmatched rows are left for the UI.

Rules: **never overwrite an existing link** (this alone protects manual work —
no provenance column needed); safe to re-run any time. Returns a summary
(`%{code: n, name: n, left: n}`)
for the flash/status line. Per-country runs are milliseconds → run inline from
the LiveView (`start_async`); a "code-pass all countries" bulk action can go
through `ExclusiveTaskProcessor` (key `{:ebird_match, :all}`).

### 5.3 Manual resolution (admin UI, §8.3)

- **Link** — pick a common location for an unmatched eBird row
  (`LocationAutocomplete` scoped to the country's common locations).
- **Unlink** — clear `location_id`.
- **Create from eBird** — make a common location from the eBird row (name from
  `name`, slug from the eBird code downcased `-`→`_`, parent = the linked
  common parent, `import_source: :ebird_regions`) and link it.
  This is how eBird-only regions (Kosovo …) and later sub2s enter; junk
  pseudo-regions (XX high seas) are simply *left unmatched deliberately* —
  consider an explicit "ignored" marker only if the noise bothers us (open
  question §10).

ISO-only subdivisions need **no action** — they already exist as common
locations and simply have no eBird counterpart (the Hungary case).

## 6. subdivision2 import (country by country)

`Sub2Import.import_country(country_code)` — enabled only when the country is
ready (§5.1):

- For each eBird sub2 row of the country: find the common subdivision1 via the
  *linked* eBird sub1 row (`subnational1Code` → its `location_id`), create a
  common `subdivision2` under it, link the sub2 row to it.
- Slug from the eBird code (`us_al_001` style — same scheme as ISO slugs,
  globally unique, stable). Name from `name`. `import_source: :ebird_regions`.
- Idempotent: skips already-linked rows; re-run freshens nothing (creation
  only). Runs in one `Repo.transact/1`.
- Only ~10 countries have sub2 data (US 3139, IN 641, PT 308, CA 294, GB 109,
  NZ 82, ES 41, ID 33, IE 26, GQ 7) — a per-country button in the admin UI is
  exactly the right granularity. US/IN are the biggest; still a single quick
  transaction, but run via `ExclusiveTaskProcessor` (key
  `{:sub2_import, country_code}`) so double-clicks and slow runs are safe.

Note: GB/ES sub2s may have real ISO 3166-2 codes; we deliberately *don't* try
to reconcile that now — they enter as eBird-created rows, `iso_code` nil.

## 7. Dump & restore (CSV on S3)

### 7.1 Format

Two CSVs, fixed S3 keys (e.g. `geo/common_locations.csv`,
`geo/ebird_locations.csv`); history via S3 bucket versioning rather than
timestamped keys.

- **common_locations.csv** — all `user_id IS NULL` rows, all persisted columns
  that matter: `id, slug, name_en, location_type, iso_code, lat, lon,
  is_private, public_index, import_source, extras (JSON), country_id,
  subdivision1_id, subdivision2_id, city_id, site_id`. Ordered parents-first
  (by level, then id) so a restore can insert in one pass.
- **ebird_locations.csv** — `code, location_type, country_code,
  subnational1_code, subnational2_code, local_abbrev, name, name_long,
  name_short, nice_name, location_id`. No id (nothing references it); `code`
  is the key.

CSV via the `csv` package (already a dependency of `ornithologue`; add
`{:csv, "~> 3.0"}` to `apps/kjogvi`).

### 7.2 Restore semantics

- **Common locations**: upsert **on `id`** (`insert_all … on_conflict`,
  chunked) — this is what keeps `location_id`, level FKs, and checklist FKs
  valid across environments (same philosophy as the images'
  `storage_backend`: data carries its own identity). Refresh the curated
  columns; bump `locations_id_seq` afterwards (reuse the ISO import's
  `GREATEST(max id, 10_000)` approach). Never touches user-owned rows.
- **eBird locations**: upsert on `code`, replacing all columns including
  `location_id` (the dump *is* the curated state).
- Deletions are **not** propagated (a row dropped from the dump stays in the
  DB) — same open TODO as the ISO import; acceptable for now, note it in the
  moduledoc.
- Restores run through `ExclusiveTaskProcessor` (keys `{:geo_restore,
  :common}` / `{:geo_restore, :ebird}`): bulk writes shouldn't run twice
  concurrently, and the shared status plays nicely with the imports page UI.

### 7.3 Storage adapters (local by default, S3 in prod)

Follow the `Ornitho.StreamImporter` pattern exactly: storage goes behind an
adapter under `Kjogvi.Datasets` — a universal snapshot-storage layer, not
geo-specific, so future dataset dumps reuse it as-is. The base config defaults
to the **local** adapter, and the S3 adapter
is wired only inside runtime.exs's `config_env() == :prod` block. Dev and test
never see S3 credentials, so a dev machine *cannot* overwrite the prod
snapshots or restore from them by accident — it operates on local files under a
configured directory (e.g. `tmp/datasets/`, gitignored):

```elixir
# config.exs (default everywhere)
config :kjogvi, Kjogvi.Datasets,
  adapter: Kjogvi.Datasets.LocalAdapter,
  path: "tmp/datasets"

# runtime.exs, inside the :prod block only
config :kjogvi, Kjogvi.Datasets,
  adapter: Kjogvi.Datasets.S3Adapter,
  bucket: System.get_env("KJOGVI_DATASETS_BUCKET"),
  region: System.get_env("KJOGVI_DATASETS_REGION"),
  access_key_id: …, secret_access_key: …   # optional, falls back to global chain
```

A commented S3 block in `dev.exs` (as with the ornitho importer) is the
deliberate opt-in for the rare "seed my dev DB from the real snapshots" case.

`Dump.run(dataset)` / `Restore.run(dataset)` read and write through whichever
adapter is configured — the admin UI calls the same functions in every env, and
in dev the whole loop just round-trips local CSV files. The local bootstrap
scripts and tests can also pass an explicit path (`Dump.to_file/2`,
`Restore.from_file/2`) to bypass config. (First prod upload can even be
`aws s3 cp` by hand — the S3 adapter just makes the admin-UI loop
self-contained.)

## 8. Admin UI (all under `/admin`, existing `live_session :admin_paths`)

Datasets are managed by admins in the admin area; the `/my` locations UI stays
untouched (it's for the user's own locations). Common locations and eBird
locations get separate indexes (`/admin/locations`, `/admin/ebird`), not tabs
of one page. New nav links in the private layout's admin section.

### 8.1 `/admin/imports/locations` — dataset operations page

(Other imports will get their own pages under `/admin/imports/…`.)

Card layout like `Live.My.Imports.Index`, one card per operation:

- **Restore common locations** (+ shows current counts by type)
- **Restore eBird locations** (+ counts, matched/unmatched totals)
- **Dump common locations** / **Dump eBird locations**
  (dumps after a curation session; shows last-modified of the snapshot)

All four go through the configured storage adapter (§7.3) — S3 in prod, local
files in dev — so the page works identically everywhere.
- **ISO 3166 import** — the existing `Imports.Locations` component, moved here
  from `/my/imports` (it was admin-gated there anyway). Kept as the bootstrap /
  "newer ISO release" tool.
- **eBird regions import** — bootstrap card mirroring the ISO one, reading its
  source from the datasets storage (§4.1). Both bootstrap cards sit in an
  "Initial Imports" section below the dataset cards.

`/my/imports` keeps Legacy and eBird-preload (user-data imports) only.

### 8.2 `/admin/locations` — common locations management

**Separate LiveView, shared rendering.** Reusing `My.Locations.Index` whole
was considered, but it diverges on too much: data assembly (`Geo.location_tree`
deliberately drops the untouched common scaffold — exactly what admin must
show — and the admin scope would also pull in every user's personal
locations), page title, header actions/counts, ownership-gated delete, link
targets, and the search filter; phase 7 then adds admin-only badges and
filters. Instead the tree machinery (`tree_node`, `tree_toggle`,
`location_card` usage) is extracted from `My.Locations.Index` into a shared
component module both LiveViews use. The cards stay similar but not identical:
the admin variant drops the Lifelist link and may grow extra admin-only
details later, so `location_card` takes options (or grows an `:admin` variant)
rather than being rendered verbatim.

- **Index**: the common scaffold as the familiar collapsible tree — fine at
  today's scale (~250 countries visible, sub1 collapsed). When sub2 imports
  grow the scaffold toward ~9k rows, either lazy-load branches on expand or
  switch to drill-down. In phase 7 country rows gain the **eBird match badge**
  (derived status, §5.1) plus filter chips by status
  (`all · matched · partial · unmatched · iso-extra…`) and text search — the
  "which countries are ready" dashboard the whole effort revolves around.
- **Show page**: the common location with its ancestors and direct children
  (adapting `My.Locations.Show` the same way — shared parts extracted, admin
  LV separate); later, per-country actions: *run match*, *import sub2s*, and a
  link to the matching workbench (§8.3).
- **CRUD**: new/edit forms for common locations (adapting `My.Locations.Form`).
  Requires an authorization change in `Kjogvi.Geo`: `create_location` /
  `update_location` / `delete_location` currently allow only owners
  (`User.owns?`), so common rows are editable by no one. Add an admin-scope
  path: `scope.area == :admin` may manage common (`user_id IS NULL`) locations;
  creation in the admin area sets `user_id: nil`.

### 8.3 `/admin/ebird` — eBird locations management

- **Index**: eBird countries with match status, matched/total counts, filters —
  the eBird-side mirror of 8.2 (may even be the same LiveView behind two
  routes if they converge; decide during implementation).
- **Country workbench** (`/admin/ebird/:country_code`): the matching UI —
  matched pairs (eBird row ↔ common location, with a derived code-match
  indicator), unmatched
  eBird rows with *link* (autocomplete) / *create from eBird* actions,
  unmatched ISO subdivisions listed for context (no action needed), *unlink* on
  matched rows, and the *run code/name match* buttons with the returned
  summary.

Keep it plain and honest per house style: `<ul>`/`<li>` lists, badges as text
chips not icon soup, responsive, no truncation.

## 9. Phased delivery (each phase = review gate, per staged-work rule)

Roughly one PR-sized stage each; tests ride with their phase. The common
locations track comes first; all eBird work is deferred until it's done.

**Track A — common locations**

1. **Common locations admin UI, read-only** — `/admin/locations` index + show
   page (no edit/add yet; no eBird badges yet), admin nav links. Works off the
   ISO-imported scaffold already in the DB, and doubles as the inspection tool
   for verifying phase 2's restores.
2. **Dump/restore core** — `Geo.Dump` / `Geo.Restore` for the common locations
   dataset **only** (the eBird dataset is added in phase 4), CSV round-trip
   tests (incl. id preservation, sequence bump, user-rows untouched). `Kjogvi.Datasets` storage adapters (§7.3): local
   adapter as the default plus the prod-only S3 adapter (S3 calls kept thin;
   tests stay on local files).
3. **Admin imports page** — `/admin/imports` with the restore/dump cards
   (ExclusiveTaskProcessor-backed), ISO card moved over from `/my/imports`.
   *Then run locally: ISO import → dump → upload to S3.*

**Track B — eBird (deferred)**

4. **eBird bootstrap import** — `Ebird.Import.from_json/1`,
   `EbirdLocation.Query` skeleton (schema already exists on this branch).
   Tests with a small JSON fixture; extend dump/restore + imports page to the
   eBird dataset. *Then run the import locally against the real file.*
5. **Matcher** — code + name passes, derived country statuses in
   `EbirdLocation.Query`. Pure-logic tests (normalization, ambiguity,
   idempotence, never-overwrite-manual).
6. **eBird admin UI** — `/admin/ebird` index + country workbench (run match,
   link/unlink, create-from-eBird). *Then start actually matching countries,
   dumping to S3 as they land.*
7. **Common locations admin UI, full** — eBird status badges and filters on
   the index, CRUD (+ the Geo authorization change).
8. **sub2 import** — `Sub2Import` + per-country action in the UI.
9. **Cleanup** — the ISO card stays (it reads its source from the datasets
   storage and remains the "newer ISO release" tool; the HTTP-URL import path +
   `LOCATIONS_IMPORT_URL` were already dropped in stage 3); set the
   `KJOGVI_DATASETS_*` env vars in prod; README/AGENTS notes.

Phases 6 and 7 are swappable; 5 must precede both (badges need statuses).
Curation (matching real countries) starts after 6 and proceeds in parallel
with 7–8 — that's the "gradual" part, and dumps to S3 checkpoint it.

## 10. Open questions (confirm before/while implementing)

1. **Status labels** — §5.1 proposes derived statuses replacing "fully matched
   / code matched / added from iso / smth else"; do the semantics match your
   intent (esp. `matched_iso_extra` for Hungary)?
2. **Ignored eBird rows** — is "leave junk regions (XX, ABA-style) unmatched
   forever" acceptable, or do you want an explicit ignored flag so `partial`
   filters aren't polluted?
3. **Sub2 slugs** — eBird-code-based (`us_al_001`, stable/unique, proposed) vs
   name-based (readable, collision-prone)?

The work is supposed to be performed in stages, with commit after every stage. Do not start work
on a new stage unless specifically instructed. Ideally after each stage the tests should pass,
but it is acceptable not to fix tests related to features that will be changed in the next 
stages, especially if this requires writing code (app or test) just for the sake of fixing the tests, and that will be removed in the future stages.

## 11. Implementation log

- **Stage 1** (2026-07-01) — Read-only common locations admin UI: `/admin/locations`
  index (full common scaffold as a collapsible tree, countries collapsed) and
  show page (details, ancestors, common children only; no actions). Tree
  machinery (`tree_node`, `tree_toggle`) extracted from `My.Locations.Index`
  into `LocationComponents` with an `admin` option (admin link targets, no
  lifelist link). New: `Location.Query.only_common/1`,
  `Geo.common_location_tree/0`, `Geo.common_location_by_slug/1`,
  `Geo.common_direct_children/1`. Admin nav link "Common Locations".
- **Stage 1a** (2026-07-01) — Text search on `/admin/locations`: same search UX
  as `/my/locations` (SearchInput, 2-char minimum, tree hidden while searching),
  backed by `Geo.search_common_locations/1` (common only, specials excluded);
  results render admin-variant cards.
- **Stage 1b** (2026-07-01) — Menu split: the old "admin menu" bar is renamed to
  what it was — the private/personal menu (`private_menu` partial, `#private-menu`) —
  and admin links move to a separate admin-only bar (`admin_menu` partial,
  `#admin-menu`: Common Locations, Taxonomy, Exclusive Tasks, Live Dashboard,
  Dev Mailbox) rendered below it in both layouts. `AdminMenuComponents.admin_menu_item`
  → `MenuBarComponents.menu_bar_item`.
- **Stage 2** (2026-07-01) — Dump/restore core for the common locations dataset:
  `Kjogvi.Geo.Dump` / `Kjogvi.Geo.Restore` (CSV, upsert on `id`, user-owned id
  collisions abort the restore, sequence bump afterwards) with `run/1` through
  the configured storage and `to_file/2`/`from_file/2` for explicit paths.
  `Kjogvi.Datasets` storage layer (`Adapter` behaviour, `LocalAdapter` default
  via config.exs `priv/datasets`, `S3Adapter` wired prod-only in runtime.exs via
  `KJOGVI_DATASETS_*`; commented opt-in block in dev.exs). Rode along per §3:
  `:iso`/`:ebird_regions` in `Kjogvi.Types.ImportSource`, the ISO import now
  stamps `import_source: :iso`; `bump_id_sequence/0` moved to `Location.Query`.
  Telemetry spans `[:kjogvi, :geo, :dump]`/`[:kjogvi, :geo, :restore]` + logger
  handlers. `{:csv, "~> 3.0"}` added to `apps/kjogvi`.
- **Stage 3** (2026-07-02) — Admin imports page: `/admin/imports/locations`
  (`Live.Admin.Imports.Locations.Index`) with Restore / Dump cards for the
  common locations dataset, run through `ExclusiveTaskProcessor` (keys
  `{:geo_restore, :common}` / `{:geo_dump, :common}`; page subscribes to both
  key topics and follows lifecycle events). Restore card shows common counts by
  type (`Geo.common_location_counts_by_type/0`, new) and is disabled without a
  snapshot; dump card shows the snapshot's last-modified
  (`Datasets.last_modified/1`, new adapter callback — local file mtime, S3
  HEAD + Last-Modified). ISO card moved from `/my/imports` (component renamed
  `My.Imports.Locations` → `Admin.Imports.Locations.Iso`; `/my/imports` keeps
  Legacy + eBird preload). Admin menu link "Imports". The ISO source JSONL also
  moved into the datasets storage under `geo/sources/iso_3166.jsonl`
  (`Import.source_key/0`): `Geo.Import` now reads it via `Datasets.read/1`
  (read-only — uploaded out-of-band), the HTTP-URL path and
  `LOCATIONS_IMPORT_URL` are gone, and `build_iso_3166.exs` defaults its output
  to `priv/datasets/geo/sources/`.
- **Stage 4** (2026-07-10) — eBird bootstrap import + dataset plumbing:
  `Geo.Ebird.Import.from_json/1` (chunked upsert on `code`, refreshes name
  fields, never touches `location_id`, skips and reports no-`countryCode`
  pseudo-rows; telemetry `[:kjogvi, :geo, :ebird, :import]` + logger handler).
  `EbirdLocation.Query` skeleton (`order_by_code`, `for_country`, `matched`,
  `count_by_type_with_matched`) and `Geo.ebird_location_counts_by_type/0`.
  Dump/Restore extended to the `:ebird_locations` dataset
  (`geo/ebird_locations.csv`, ordered by `code`; restore upserts on `code`
  replacing everything incl. `location_id`, clearing existing links first so
  a link that moved between codes can't hit the unique index). Imports page
  got Restore/Dump eBird cards (keys `{:geo_restore, :ebird}` /
  `{:geo_dump, :ebird}`; restore card shows per-type totals + matched counts);
  restore/dump cards refactored into shared `restore_card`/`dump_card`
  components, notice ids now card-prefixed. The eBird import also got a web UI
  card mirroring the ISO one (`Imports.Locations.Ebird`; `Import.import/0`
  reads the source from the datasets storage under
  `geo/sources/all_ebird_locs.json`); the two bootstrap import cards sit in
  their own "Initial Imports" section below the dataset cards. *Ran the real
  import locally: 8,489 regions (252 countries, 3,557 sub1, 4,680 sub2),
  skipped `aba`; source JSON placed in `priv/datasets/geo/sources/`.*
- **Stage 5** (2026-07-10) — Matcher + derived statuses:
  `Geo.Ebird.Matcher.match_country/2` (country pass, code pass, name pass on
  leftovers via public `normalize_name/1` — NFD, strip diacritics, downcase,
  collapse punctuation/whitespace; unambiguous 1:1 only). All passes in one
  `Repo.transact/1`; never overwrites a link (`is_nil(location_id)` guards) and
  never takes a common location linked from another eBird row; sub2 rows are
  invisible to matching and statuses (linked by the stage-8 import). Returns
  `%{code: n, name: n, left: n}`; telemetry `[:kjogvi, :geo, :ebird, :match]`
  + logger handlers. `EbirdLocation.Query` grew the link-update queries, the
  stat aggregations (`country_match_stats`, `sub1_match_stats`,
  `iso_sub1_stats` — anchored on the linked common country, so manually linked
  eBird-only countries work) and pure `derive_status/1` (§5.1 statuses,
  iso_extra outranks mixed per confirmed Q1; Q2 confirmed: junk rows stay
  unmatched, no ignored flag). `Geo.ebird_country_statuses/0` /
  `ebird_country_status/1` merge the stats and add `:status`.
  `ebird_location_factory` now derives `country_code` from a passed `code`;
  new `ebird_subdivision1_factory`. *Sanity-run on the real data: AD
  `%{code: 8, name: 0, left: 0}` → `:matched`; CZ (zero code overlap)
  `%{code: 1, name: 13, left: 1}` → `:partial`; HU `%{code: 43, name: 0,
  left: 0}` → `:matched_iso_extra` (the Hungary case); re-runs are no-ops.*
