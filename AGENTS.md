# Kjógvi Codebase Instructions for AI Agents

This file is the source of truth. [`PHOENIX.md`](./PHOENIX.md) holds the stock, auto-generated Phoenix/Elixir usage rules; where they conflict, this file wins.

## Project Overview

**Kjógvi** is a Phoenix v1.8 umbrella project for bird observation tracking with ornithological taxonomy management. It combines birding/observation records with a comprehensive taxonomy system via the [Ornithologue](./apps/ornithologue/) library.

It is a **multi-user app**: any number of users register, keep their own birding records, and upload images. Registration can be closed via settings (see `Kjogvi.Settings`).

### Areas (scope)

Every request runs in an **area**, carried by `Kjogvi.Scope` (`apps/kjogvi/lib/kjogvi/scope.ex`). The area decides whose data is visible and whether private data is included:

- `:community` — aggregate public data across all users (the default). Routes under `/community`.
- `:user` — public data of a specific `subject_user`. Routes under `/users/:username`.
- `:private` — all data (incl. private) of the logged-in `current_user`. Routes under `/my`.
- `:admin` — administrative area. Routes under `/admin` (taxonomy, dashboard, exclusive tasks).

The browser pipeline calls `fetch_current_scope`; each scoped route group sets its area via `put_area_*` plugs and `mount_area_*` on_mounts (`KjogviWeb.UserAuth`). The scope struct holds `current_user`, `subject_user`, and `area`.

**One LiveView often serves several areas** with different input data — e.g. `Live.Lifelist.Index` renders the community lifelist (`/community/lifelist`), a public user lifelist (`/users/:username/lifelist`), and the private lifelist (`/my/lifelist`); likewise `Live.Photos.Index`. Such LVs branch on `scope.area` rather than being duplicated.

### Architecture
- **Umbrella structure** with 4 apps in `/apps`:
  - `kjogvi`: Core business logic, data models, and contexts
  - `kjogvi_web`: Phoenix 1.8 LiveView web interface (main app)
  - `ornithologue`: Ornithological taxonomy library (reusable package)
  - `ornitho_web`: Taxonomy dashboard UI (composable into `kjogvi_web`)
- One Ecto repo (`Kjogvi.Repo`); taxonomy tables live in the `ornithologue` Postgres schema — see [Database / Ecto](#database--ecto).

## Critical Development Workflows

```bash
# Setup
mix setup                           # Install deps in all apps
docker compose up -d                # Start PostgreSQL (port 5498)

# Development
iex -S mix phx.server              # Start with IEx shell

# Testing & Quality
mix lint.fix                       # Auto-fix formatting + run lint (run before committing)
mix lint                           # Full linting: credo, dialyzer, xref cycles
MIX_ENV=test mix ecto.setup        # Create test database
mix test                           # Run tests with coverage

# Database
mix ecto.create                    # Create database
mix ecto.migrate                   # Run migrations
```

## Project-Specific Patterns

### Router
Routes are grouped by area (`/community`, `/users/:username`, `/my`, `/admin`), each with its own `pipe_through`, `put_area_*` plug, `live_session`, and `mount_area_*` on_mount. `/my` requires `:require_authenticated_user`; `/admin` requires `:require_admin`. The whole site is gated by `:require_setup`, which redirects to `/setup` until an admin user exists.

### Settings
[`Kjogvi.Settings`](./apps/kjogvi/lib/kjogvi/settings.ex) exposes site-wide feature flags / kill switches as intention-revealing functions (`registration_disabled?/0`, `forgot_reset_password_disabled?/0`, `confirmation_disabled?/0`). Values come from app config today; the private `get/2` is the single seam to swap for a DB lookup later.

### Auth LiveViews
Account/auth LiveViews live under `Live.Accounts.*` and are mounted at `/account` (login, register, reset-password, confirm). Registration also has a no-JS POST path (`/account/register`).

### Forms
Use `to_form(changeset)` in LiveView, access via `@form[:field]` in templates. Never pass `@changeset` to templates.

### LiveView data
Default to plain assigns and lists. Don't reach for streams reflexively — use a stream only where it's genuinely warranted (large or append-heavy collections), not as the go-to.

### Components
[`CoreComponents`](./apps/kjogvi_web/lib/kjogvi_web/components/core_components.ex) (`<.icon>`, `<.input>`, `<.button>`, `<.flash>`, etc.) is the stock module Phoenix generates. It's kept largely as-is for reference and should be replaced over time by more specific, purpose-built components for this app — prefer (or add) a dedicated component over reaching for a generic CoreComponent.

### Icons
Heroicons via the `<.icon>` component (e.g. `name="hero-star-solid"`); the bicycle is a bundled inline-SVG variant: `<.icon name="bicycle" />`.

### Database / Ecto
One repo, `Kjogvi.Repo`. Taxonomy tables live in the same database under the `ornithologue` Postgres schema: `config :ornithologue, repo: Kjogvi.Repo, prefix: "ornithologue"` — the [Ornithologue](./apps/ornithologue/) library applies the prefix to all its operations via its `Ornitho.Repo` facade. Never query the taxonomy tables through `Kjogvi.Repo` directly; go through the Ornitho API (`Ornitho.Finder.*`, `Ornitho.Ops.*`), which handles the prefix. The `ornithologue` schema is installed by a regular main-repo migration calling `Ornitho.Migrations.up/1`.

### Queries vs. context logic
Keep query-building out of context modules. Each schema has a dedicated `<Schema>.Query` submodule (e.g. [`Kjogvi.Geo.Location.Query`](./apps/kjogvi/lib/kjogvi/geo/location/query.ex), `Birding.Checklist.Query`, `Birding.Lifelist.Query`) that owns `import Ecto.Query` and exposes composable functions returning queries. Contexts call those functions and run the result; prefer **not** to `import Ecto.Query` in a context. Some older contexts still import it directly — that's the pattern being migrated away from, so new/changed code should add or extend a `Query` module instead.

### Telemetry
Prefer `:telemetry` for cross-cutting concerns: emit `:telemetry` events for logging and for lifecycle / domain events, and attach handlers (or PubSub broadcasts) to react to them — rather than threading logging and side-effects directly through business logic. This keeps contexts focused on their core work and observable from the outside.

### Birding Data
[`Kjogvi.Birding`](./apps/kjogvi/lib/kjogvi/birding.ex) is the checklists-and-observations context. A `Checklist` is a checklist — one dated visit at a `Location` (effort, weather, observers, …) — that `has_many` `Observation`s, each recording a taxon seen. Checklists are user-owned.

### Locations
Locations live in [`Kjogvi.Geo`](./apps/kjogvi/lib/kjogvi/geo.ex), with the [`Location`](./apps/kjogvi/lib/kjogvi/geo/location.ex) schema and its [`Location.Query`](./apps/kjogvi/lib/kjogvi/geo/location/query.ex) module. Every location has a required `location_type` and is either **user-belonging** (a `user_id` owner, managed by and private to that user) or **common** (a `nil` owner, shared across all users — see `Query.for_user/2`). The intended split: `country` and `subdivision1` are common, everything below is user-belonging; lower-level common locations (counties, cities, hotspots) may be added over time.

**Hierarchy via denormalized level FKs.** The ordered levels, top to bottom, are `country → subdivision1 → subdivision2 → city → site → section`. A location's place in the tree is stored not as a single `parent_id` but as one FK per level *above* `section`: `country_id, subdivision1_id, subdivision2_id, city_id, site_id`. Each names the ancestor at that level directly, so "everything under a country", a location's ancestor chain, and its full display name are plain FK reads — no recursion. `section` is the lowest level and is never an ancestor, so it has no FK column. Levels are skippable (a city may hang directly off a country).

- **Editing** sets a virtual `parent_id`; `Location.changeset/2` derives the five level FKs from the chosen parent (`level_fks_from_parent/1`). `parent_id_from_levels/1` / `ancestor_ids/1` read them back.
- **Invariants** are enforced in the changeset (`validate_slot_occupancy/2`): no FK at the location's own level or below, every non-country belongs to a country, and each ancestor's higher FKs stay prefix-consistent. Changing a `location_type` is band-checked (`validate_location_type_change/1`) and cascades descendants' FKs onto the new level column (`Geo.update_location/3` → `Query.move_descendants/3`).
- **Descendant queries** read the level FKs in reverse: `Query.child_locations/1` (self + all descendants), `Query.direct_children/1` (immediate children only).

**`special` type.** A `special` sits *outside* the ordered levels — it has no level of its own, so slot-occupancy is not enforced on it and it cannot be a hierarchy parent — and is an amalgamation of member locations joined via the `special_locations` table (`special_child_locations` / `special_parent_locations`). It *does* still carry level FKs: like any location it is placed under a parent, and the user is responsible for picking one that is the common denominator of its members (e.g. Lower 48 goes under United States). A multi-country special is simply left without a parent. A checklist counts toward a special when its location is a member or a descendant of one (`Query.special_descendant_ids/1`). Most list queries exclude specials explicitly; `Geo.get_specials/1` and `special_member_locations/1` handle them.

**Display names & privacy.** `Location.long_name/2` builds the comma-joined "own name, …, country" string from the preloaded level associations (`Query.preload_levels/1` / `level_assocs/0`). Pass `:private` to include every segment or `:public` to drop any `is_private` segment — privacy is *not* downward-closed, so a public location can still carry a private ancestor and must be filtered. `public_index` (distinct from `is_private`) marks the subset of locations offered as lifelist filters (`show_on_lifelist?/1`).

### Taxonomy
Managed by [ornithologue](./apps/ornithologue/) in the `ornithologue` DB schema; always access it through the Ornitho API. Mounted at `/taxonomy` with the `ornitho_web` macro.

### Images
[`Kjogvi.Images`](./apps/kjogvi/lib/kjogvi/images.ex) context; Waffle uploader (`Images.Uploader`) + libvips/Vix resizing (`Images.VixProcessor`). Variant filenames are computed at serve time, not stored — only the original `file` is persisted. URLs resolve against each image's own recorded `storage_backend` (not the env's current one), so images stay viewable across environments sharing a DB (prod-S3 image renders on local dev and vice versa).

### CSS
Tailwind v4 with new import syntax (no config). Never use `@apply`. Import JS into `app.js`, not inline `<script>` tags.

### Testing
`Phoenix.LiveViewTest` + `LazyHTML`. Assert elements by ID, not HTML. Test outcomes, not implementation.

## Key File References

| File | Purpose |
|------|---------|
| [mix.exs](./mix.exs) | Umbrella config, development aliases |
| [config/config.exs](./config/config.exs) | Ornithologue & Tailwind setup |
| [apps/kjogvi_web/router.ex](./apps/kjogvi_web/lib/kjogvi_web/router.ex) | Main router, area route groups, auth pipelines |
| [apps/kjogvi/lib/kjogvi/scope.ex](./apps/kjogvi/lib/kjogvi/scope.ex) | `Kjogvi.Scope`: current/subject user + area |
| [apps/kjogvi/lib/kjogvi/settings.ex](./apps/kjogvi/lib/kjogvi/settings.ex) | Site-wide settings & feature flags |
| [apps/kjogvi_web/user_auth.ex](./apps/kjogvi_web/lib/kjogvi_web/user_auth.ex) | Auth + `put_area_*`/`mount_area_*` (in plug.ex/user_auth.ex) |
| [apps/kjogvi/lib/kjogvi/birding.ex](./apps/kjogvi/lib/kjogvi/birding.ex) | Birding context & checklist logic |
| [apps/kjogvi/lib/kjogvi/geo.ex](./apps/kjogvi/lib/kjogvi/geo.ex) | Geo context: location CRUD, hierarchy & lifelist queries |
| [apps/kjogvi/lib/kjogvi/geo/location.ex](./apps/kjogvi/lib/kjogvi/geo/location.ex) | Location schema: level-FK hierarchy, types, privacy |
| [apps/kjogvi/lib/kjogvi/geo/location/query.ex](./apps/kjogvi/lib/kjogvi/geo/location/query.ex) | Location queries: descendants, specials, name preloads |

## Essential Libraries

- **Req**: HTTP client (preferred over httpoison, tesla)
- **Phoenix LiveView**
- **Ecto**
- **Scrivener** (`scrivener_ecto` + `scrivener_phoenix`): pagination — the `/page/:page` routes use it; paginate with it rather than rolling your own
- **ExAws / ExAws.S3**: S3 storage backend for images (see the `storage_backend` note under Images)
- **Waffle** (`waffle` + `waffle_ecto`): file/image uploads (see Images)
- **Cachex**: caching
- **Tailwind v4**: No config, new import syntax
- **LazyHTML**: Testing assertions

## Common Pitfalls

1. Wrong area / missing scope — put routes under the right area group so the `put_area_*` plug and `mount_area_*` on_mount set `Kjogvi.Scope`; `/my` needs `:require_authenticated_user`, `/admin` needs `:require_admin`
2. Passing `@changeset` to templates — use `@form` from `to_form/2`
3. `import Ecto.Query` in a context — build queries in the schema's `<Schema>.Query` module instead
4. Raw Heroicons instead of `<.icon>` component
5. Accessing taxonomy tables through `Kjogvi.Repo` directly — they live in the `ornithologue` schema and must be reached through the Ornitho API (`Ornitho.Finder.*` / `Ornitho.Ops.*`), which applies the configured prefix

## Notes for AI Agents

### Elixir style

- Code assertively, not defensively. Elixir isn't strictly typed, but pattern matching makes it soft-typed — let a function's clauses/patterns state the shapes it accepts and let it crash (`FunctionClauseError`, `MatchError`) on anything else, rather than adding `if is_nil(x)`/`case`/guard fallbacks to tolerate shapes that shouldn't reach it.
- Before guarding against `nil` (or another unexpected shape) at the point you noticed it, check whether it can be eliminated upstream instead — e.g. a changeset/schema default, a query that shouldn't return it, a caller that should have already branched. Prefer fixing the source over adding a defensive check downstream.
- Reserve nil/shape guards for genuine boundaries: user input, external API responses, and other data Elixir's pattern matching can't have already constrained.

### Code organization

- Avoid partial imports (`import ..., only: ...`) unless necessary. In general, only use `import` where Phoenix/LiveView prescribes it — e.g. importing function components. Otherwise prefer calling the function with its module name, plus an `alias` if it helps.
- Follow the LiveView naming pattern: `KjogviWeb.Live.Something` lives in `apps/kjogvi_web/lib/kjogvi_web/live/something.ex` (this contradicts the Phoenix recommended pattern of `KjogviWeb.SmthLive`, but is my preference).
- Avoid adding utility functions unrelated to a module's topic (whether in a LiveView or elsewhere), especially trivial ones like converting `nil` to an empty string. Put them under `Kjogvi.Util`, or avoid them altogether.
- For multi-step database writes, use `Repo.transact/1` rather than `Ecto.Multi`.

### Documentation

- Update module and function documentation when making changes.
- Keep documentation concise. Don't explain what's obvious from the code (e.g. don't write 'Returns `true` if...'), and don't describe the change you made or how the code used to work.

### Testing & committing

- Add and update tests for all new and changed code before committing.
- Check for tests verifying the same functionality.
- Before committing, run `mix lint.fix` (to auto-fix formatting + linting) and the tests.

### Frontend & accessibility

- When designing frontend, always make it responsive (check on smaller screen sizes).
- Be mindful of how it will present on text-based browsers (e.g. lynx) and for screen readers.
- When creating a bunch of homogenous elements, implement them using `<ul>` and `<li>`, even if they are not rendered visually as a list.
- Do not overuse icons.
- Don't truncate text (CSS `truncate`, `…`, or otherwise) unless explicitly asked.
- In HEEx, don't let a link's text break onto its own line — a line break after the opening tag renders as a stray space (e.g. an underlined space before/after the link text). Keep the content between the opening tag's `>` and the closing `<` on one line: `<.link href={...}>Text</.link>`. If the formatter insists on wrapping it, add `phx-no-format` to the tag to suppress reformatting.

## Committing

- Never commit without explicit, in-the-moment approval. "Commit" means run `git commit` directly — the tool-confirmation dialog is the approval gate. If `git commit` would run with no confirmation prompt at all, ask first; never let a commit land with zero confirmation.
- Before committing, run `mix lint.fix` and the tests (`mix test`). Fix lint errors; pre-existing TODO/FIXME tags can be ignored.
- End the commit subject (first line) with a period.
- Use an `Assisted-by:` trailer, not `Co-Authored-By:`.
- Never override git config on commit (no `-c commit.gpgsign=false` or similar).
- For multi-stage work, stop after each stage for review before committing or continuing.

## Log papercuts

When you hit a small friction while working — a tool call that missed and had to be retried, a confusing or undocumented setup step, a flaky command, a stale cache, a misleading error, a non-obvious gotcha — log it to `PAPERCUTS.md` by appending an entry. One or two sentences: what you were doing → what got in the way (a guess at the cause/fix is a bonus). Do this proactively, in the moment, even though none of these are blocking — logged together they show where the repo needs sanding down. This is distinct from what you accomplished and from tracked bugs.
