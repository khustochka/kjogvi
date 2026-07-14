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
| Per-country matcher: country pass, code pass, name pass (unambiguous 1:1 only, names normalized incl. non-decomposing letters; never overwrites) | `Kjogvi.Geo.Ebird.Matcher.match_country/2`, *run match* in the workbench |
| Derived country statuses — mismatch *shapes* (`matched · iso_extra · name_candidate · ebird_only · mixed`), plus a separate "not fully linked" work filter | `EbirdLocation.Query.derive_status/1`, badges on both admin indexes |
| Manual resolution: link (autocomplete) / unlink / create-from-eBird | Workbench `/admin/ebird/:country_code` |
| Common locations admin CRUD (create/edit/delete, ancestry + eBird-link guards) | `/admin/locations` |
| Dump / restore of both datasets as CSV through the storage adapter (local in dev, S3 in prod) | `Kjogvi.Geo.Dump` / `Kjogvi.Geo.Restore`, cards on `/admin/imports/locations` |
| Raw-import guards: bootstrap card disabled once the dataset has rows, confirm when empty but a snapshot exists | `Kjogvi.Geo.Import.Guard`, both cards on `/admin/imports/locations` |

Not yet built: the bulk code pass (`match_all`) that links every clean country
in one action, the subdivision2 import (§5). The derived statuses that classify
each country by mismatch shape already exist.

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

**A country is the atomic triage unit.** Its rows are linked all-or-nothing —
the bulk pass and each manual fix link a whole country at once. This gives two
**independent axes**, kept as two separate filter dimensions on `/admin/ebird`:

- **Status = the mismatch *shape*** of the eBird-vs-ISO subdivision sets:
  `matched · iso_extra · name_candidate · ebird_only · mixed`. It is a property
  of the *sets*, computed regardless of link progress — a perfect code-set match
  reads `matched` even before the pass physically links it. Link state never
  enters the status: a country linked by some non-code pairing still shows its
  set shape.
- **Link completeness = the work queue.** The *"not fully linked"* filter picks
  out every country that still has eBird rows to link — the actual to-do list —
  orthogonally to its shape. A perfect-match country the bulk pass hasn't run on
  yet reads `matched` *and* appears under "not fully linked".

The status **is** the triage classification: the badges on `/admin/ebird` (and
mirrored on `/admin/locations`) are the dashboard, and everything not `matched`
names its own mismatch shape — `iso_extra`, `name_candidate`, `ebird_only`,
`mixed` (§3.3). No separate hint layer: the shape you see is the status.

### 3.3 Triage: per-country review playbook

Filter to **not fully linked** for the work queue, then work through it by shape
in the workbench. The status names the shape and the fix (all set comparisons
are over the *full* eBird and ISO subdivision1 sets; names are compared
normalized — diacritics and non-decomposing letters folded, so "Łódzkie"
matches "Lodzkie"):

| Status | Shape | Action |
|---|---|---|
| `matched` | The eBird and ISO subdivision1 code sets are identical (a perfect match — including no subdivisions on either side) | *Run match* / the bulk pass links every row with no leftovers |
| `iso_extra` | Every eBird subdivision1 code is among the ISO country's codes, but ISO has more (subdivisions eBird doesn't cover) | *Run match* — the code pass links every eBird row; the ISO extras stay as valid common locations eBird simply lacks |
| `name_candidate` | Codes differ but the eBird and ISO subdivision1 *name* sets are equal (the Poland case: same woewodships, alphabetic → numeric codes) | *Run match* — the name pass auto-links the unambiguous 1:1 name matches; resolve any leftovers |
| `ebird_only` | The eBird country has no ISO counterpart at all | *Create from eBird* — makes the common country and links it; then match its subdivisions |
| `mixed` | The eBird and ISO subdivisions overlap only partially — by neither code set nor whole name set (junk pseudo-regions like the high seas, word-order name differences, a genuine no-match) | Manual: *link* via autocomplete / *create from eBird* where warranted, or leave unlinked deliberately (unlinked is the "ignored" state) |
| *(no eBird row)* | Country exists in ISO but not in eBird | Nothing — a valid common location eBird simply doesn't know |

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
2. **Triage statuses** *(done — `EbirdLocation.Query.derive_status/1`)* — the
   per-country classification by mismatch shape (`matched`, `iso_extra`,
   `name_candidate`, `ebird_only`, `mixed`; §3.2–3.3), derived over the full
   eBird-vs-ISO subdivision sets in `Kjogvi.Geo.Ebird`, independent of link
   state. Pure derivation, no schema. Names compared via
   `Matcher.normalize_name/1`, which also folds non-decomposing Latin letters
   (ł, ø, ß, …) so eBird's flattened spellings match ISO's. Badges + status
   filter on `/admin/ebird` and `/admin/locations`, plus a separate "not fully
   linked" work filter on the eBird index; the eBird index shows each linked
   country's common location.

3. **Bulk code pass** — `Matcher.match_all/0` across all eBird countries: links
   country rows by code, then links subdivision1s only for countries whose
   eBird and ISO subdivision1 code sets match exactly (or that have none); any
   discrepancy leaves the country's subdivisions untouched (§3.2). No name pass.
   Run via `start_async` from a button on `/admin/ebird` (the pass is a handful
   of `UPDATE`s in one transaction, sub-second — same pattern as the eBird
   import card; the `is_nil` link guards make concurrent/repeat runs safe, so
   no exclusive-task machinery). A run summary flash; the status badges refresh
   to show the newly-`matched` countries. Note it is *stricter* than
   `match_country/2`'s code pass, which links any code match: the all-or-nothing
   set check is new logic, not just composition.
4. **subdivision2 import** — `Sub2Import.import_country/1` per the existing
   spec (plan doc §6): enabled only for ready countries, creates linked common
   subdivision2s (slug from the eBird code), exclusive task per country,
   per-country button. Medium.

Item 1 makes the workflow safe; items 2–3 make starting fast and hand review a
pre-classified list; item 4 fills out the long tail. Curation itself (§3.3)
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
