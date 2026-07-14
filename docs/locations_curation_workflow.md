# Locations Curation Workflow

Status: proposal · 2026-07-13 · Branch: `ebird-locations-map`

The end-to-end workflow for building a **curated common-locations dataset fully
matched to eBird's region tree**, and the pieces still to implement for it.
Self-contained; [`ebird_locations_plan.md`](./ebird_locations_plan.md) holds the
implementation staging detail and history for the parts already built.

## 1. Goal and principles

Two datasets are being curated:

- **Common locations** — `locations` rows with `user_id IS NULL`: countries and
  subdivision1s seeded from ISO 3166, growing subdivision2s and hand-made
  locations over time. Referenced by id from user locations, checklists, and
  eBird links, so **ids must stay stable across environments**.
- **eBird regions** — `ebird_locations`: a reference copy of eBird's region
  tree, keyed by `code`. Its `location_id` column links each region to a common
  location and *is* the entire match state.

Principles the whole workflow rests on:

1. **Raw sources are bootstrap-only.** The ISO JSONL and the eBird region JSON
   seed an empty database once. After that, curation happens in the DB and is
   checkpointed to storage.
2. **The snapshot in storage is canonical.** Once the first dump lands, any
   environment (or a reset local DB) is seeded by *restore*, never by
   re-running raw imports.
3. **Automation never destroys manual work.** Matching passes only fill empty
   `location_id`s; restores upsert rather than wipe; raw imports are refused
   once a dataset has rows (§4).
4. **Everything is re-runnable.** Every pass and import is idempotent; running
   it twice is a no-op.

## 2. What already exists

| Piece | Where |
|---|---|
| ISO 3166 bootstrap import (countries + subdivision1s, upsert on `iso_code`) | `Kjogvi.Geo.Import`, card on `/admin/imports/locations` |
| eBird region bootstrap import (upsert on `code`, never touches `location_id`) | `Kjogvi.Geo.Ebird.Import`, card on same page |
| Per-country matcher: country pass, code pass, name pass (unambiguous 1:1 only; never overwrites) | `Kjogvi.Geo.Ebird.Matcher.match_country/2`, *run match* in the workbench |
| Derived country statuses (`matched · matched_mixed · matched_iso_extra · partial · unmatched`) | `EbirdLocation.Query.derive_status/1`, badges on both admin indexes |
| Manual resolution: link (autocomplete) / unlink / create-from-eBird | Workbench `/admin/ebird/:country_code` |
| Common locations admin CRUD (create/edit/delete, ancestry + eBird-link guards) | `/admin/locations` |
| Dump / restore of both datasets as CSV through the storage adapter (local in dev, S3 in prod) | `Kjogvi.Geo.Dump` / `Kjogvi.Geo.Restore`, cards on `/admin/imports/locations` |
| Raw-import guards: bootstrap card disabled once the dataset has rows, confirm when empty but a snapshot exists | `Kjogvi.Geo.Import.Guard`, both cards on `/admin/imports/locations` |

Not yet built: the bulk code pass with its triage hints, the subdivision2
import (§5).

## 3. The workflow

### 3.1 Bootstrap (once, into an empty DB, locally)

1. Place the raw sources in the datasets storage
   (`geo/sources/iso_3166.jsonl`, `geo/sources/ebird_subregions.jsonl`).
2. Run the **ISO import** — common countries + subdivision1s appear.
3. Run the **eBird import** — the eBird region tree appears, fully unlinked.

Order matters only in that matching needs both sides present. ISO-side edits
(step 3 of the mental model) are possible at any point from here on — §3.6.

### 3.2 Bulk auto-match: the code pass

Run the **bulk code pass** (to implement, §5.2) once over all countries. It
links eBird country rows to common countries by code, and links a country's
subdivision1s **only when the country fully matches**: its eBird and ISO
subdivision1 code sets are identical (or it has no subdivision1s at all).
Those countries land directly in `matched`. Any code discrepancy — extra codes
on either side, partial overlap — leaves the country's subdivisions entirely
untouched, so every country that needs eyes arrives at review whole, with no
half-automatic link set to untangle.

The name pass deliberately does **not** run in bulk: it involves judgment about
whether a country's shape suits it, so it stays a per-country decision made
during review.

After the bulk pass, the status badges on `/admin/ebird` (and mirrored on
`/admin/locations`) are the triage dashboard: everything not `matched` needs
eyes. Each such country also carries a **shape hint** derived from the same
match stats — *name-pass candidate*, *ISO-extra*, *eBird-only* (§3.3) — so
the review list arrives pre-classified rather than as a flat pile.

### 3.3 Triage: per-country review playbook

Work through the remaining countries in the workbench, by shape:

| Shape | Signal | Action |
|---|---|---|
| Codes disagree but the subdivision sets look alike (counts align, few/no code matches) | *name-pass candidate* hint | *Run match* in the workbench — the name pass auto-links unambiguous 1:1 name matches; manually resolve the leftovers |
| Every eBird subdivision has a code match, but ISO has extras (so the bulk pass skipped the country) | *ISO-extra* hint | Spot-check the extras are real, then *run match* — the code pass links every eBird row → `matched_iso_extra`, fully ready |
| Some links made, odd leftovers on both sides | `partial` | Manual per-row work: *link* via autocomplete, *create from eBird* for regions ISO lacks, or leave |
| Country exists in eBird but not in ISO | *eBird-only* hint, `unmatched` | *Create from eBird* — makes the common country and links it; then match its subdivisions |
| Junk pseudo-regions (high seas etc.) | `unmatched`, obviously not a real place | Leave unmatched deliberately — unlinked is the "ignored" state |
| Country exists in ISO but not in eBird | listed with no eBird counterpart | Nothing — it's a valid common location that eBird simply doesn't know |

Manual links are safe from automation: no pass ever overwrites an existing
`location_id`, so re-running any pass at any time costs nothing.

### 3.4 Checkpoint: dump after every session

After each curation session, dump both datasets from
`/admin/imports/locations`. The snapshots (`geo/common_locations.csv`,
`geo/ebird_locations.csv`) become the canonical state: common locations dump
with their **ids** (so restores keep every FK valid), eBird regions dump with
their links keyed by `code`. History comes from storage versioning (S3 bucket
versioning in prod), not timestamped keys.

Dump early, dump often — the snapshot is the save file.

### 3.5 subdivision2 import (per country, once matched)

When a country is fully ready (every eBird row linked), its eBird
subdivision2s can be imported as common `subdivision2` locations in one
per-country action (to implement, §5.3): each sub2 row creates a common
location under the *linked* common subdivision1 and links itself to it.
Idempotent, creation-only. Then dump.

### 3.6 Hand edits, any time

Common locations are editable throughout via `/admin/locations` CRUD — name
fixes, coordinates, new locations for regions neither source has. Deleting a
location that an eBird region links to is refused (unlink in the workbench
first), so curated match state can't be silently nilified.

### 3.7 Reset / new environment

Restore both datasets from `/admin/imports/locations` (common locations first —
eBird links reference them). Because common locations restore **by id**,
everything that referenced them keeps working. Then continue curating exactly
where the last dump left off. **Never re-bootstrap from raw sources once a
snapshot exists** — §4's guards make that a path you must deliberately confirm
past, not something to remember.

### 3.8 Newer raw releases (occasionally, much later)

Raw imports are refused once a dataset has rows (§4), so pulling a newer ISO
release or eBird region dump into the curated dataset is deliberately *not* a
UI action. When it's genuinely needed, it's a console-run affair: both imports
upsert (ISO on `iso_code`, eBird on `code`) and never touch links, so the
realistic damage is refreshed name fields overwriting hand-fixed names —
review on the admin pages afterwards, then dump. New eBird codes appear as
unmatched rows and re-enter triage (§3.3). If this ever becomes routine, the
changelog/replay ideas in §6 are the proper tooling for it.

## 4. Safety model: protecting curated state

Two sequences endanger curated work:

- **Raw import over a curated DB** — re-running a bootstrap import on top of
  hand-fixed data (the upserts refresh name fields).
- **Reset → raw import → dump** — a freshly-reset DB imports raw sources and
  dumps them over the newer curated snapshot in storage.

Both are cut off at the **raw import** (to implement, §5.1):

- **Dataset already has rows → import refused.** The bootstrap card is
  disabled with an explanation; curated in-DB state can't be trampled from
  the UI at all.
- **Dataset empty, but a snapshot exists in storage → import requires an
  explicit confirm.** After a reset the right move is *restore*; the confirm
  is the tripwire that says so. Getting from there to an overwritten snapshot
  now takes two deliberate acts (confirm the raw import, then dump) — it can
  no longer happen absentmindedly.
- **Dataset empty, no snapshot → import runs freely** (the bootstrap case).

The dump itself stays unguarded — no generation tracking, no extra tables.

**Backstop — storage versioning.** S3 bucket versioning in prod means even a
snapshot dumped over in error is recoverable by promoting the previous object
version. (Local dev snapshots are throwaway by definition.)

## 5. To implement

Roughly one PR-sized item each, in suggested order:


1. **Raw import guards** *(done — `Kjogvi.Geo.Import.Guard`)* — on both
   bootstrap cards: hard-disable (with an explanation) when the dataset already
   has rows; explicit confirm when the dataset is empty but a snapshot exists in
   storage (existence check via `Datasets.snapshot_status/1`).
2. **Bulk code pass + triage hints** — `Matcher.match_all/1` across all eBird
   countries, through `ExclusiveTaskProcessor` (key `{:ebird_match, :all}`):
   links country rows by code, then links subdivision1s only for countries
   whose eBird and ISO subdivision1 code sets match exactly (or that have
   none); any discrepancy leaves the country's subdivisions untouched (§3.2).
   No name pass. Button on `/admin/ebird` with a run summary. Note it is
   *stricter* than `match_country/2`'s code pass, which links any code match:
   the all-or-nothing set check is new logic, not just composition.
   Riding along, the **shape hints** that pre-classify the leftovers
   (§3.2–3.3): derived per country from the already-computed match stats,
   shown as text chips on the index/workbench — *name-pass candidate*
   (subdivision counts align, few code matches), *ISO-extra* (every eBird
   code matches, ISO has more), *eBird-only* (no ISO country for the code).
   Pure derivation, no schema. Medium in total.
3. **subdivision2 import** — `Sub2Import.import_country/1` per the existing
   spec (plan doc §6): enabled only for ready countries, creates linked common
   subdivision2s (slug from the eBird code), exclusive task per country,
   per-country button. Medium.

Item 1 makes the workflow safe; item 2 makes starting fast and hands review a
pre-classified list; item 3 fills out the long tail. Curation itself (§3.3)
can proceed in parallel from the moment item 1 lands.

## 6. Future ideas (deliberately deferred)

**Changelog / diffing of common locations.** Motivations, in increasing
ambition: (a) *"does the DB hold undumped changes?"* before a reset; (b) show
*what* changed between two snapshots; (c) replay curation decisions onto a
re-imported newer ISO/eBird release instead of trusting upsert semantics.
Worth noting that (a) — the most useful — may not need a changelog at all: an
on-demand **diff of the DB against the current snapshot CSV** answers it with
zero bookkeeping. An event-log/audit-table approach (telemetry on common
location writes) would serve (b) and (c) but is real machinery; not designed
now. Revisit if (a)'s diff tool proves insufficient.
