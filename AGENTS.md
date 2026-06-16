# Kjógvi Codebase Instructions for AI Agents

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
- Two Ecto repos — see [Database / Ecto](#database--ecto).

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
mix ecto.create                    # Create databases
mix ecto.migrate -r Kjogvi.Repo    # Run migrations on main repo
mix ecto.migrate -r Kjogvi.OrnithoRepo  # Run migrations on taxonomy repo
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
Two separate repos: `Kjogvi.Repo` for the main app data and `Kjogvi.OrnithoRepo` for taxonomy. They have independent migrations — run them separately (`mix ecto.migrate -r Kjogvi.Repo` vs `-r Kjogvi.OrnithoRepo`). Pick the right repo for the data you're touching.

### Queries vs. context logic
Keep query-building out of context modules. Each schema has a dedicated `<Schema>.Query` submodule (e.g. [`Kjogvi.Geo.Location.Query`](./apps/kjogvi/lib/kjogvi/geo/location/query.ex), `Birding.Card.Query`, `Birding.Lifelist.Query`) that owns `import Ecto.Query` and exposes composable functions returning queries. Contexts call those functions and run the result; prefer **not** to `import Ecto.Query` in a context. Some older contexts still import it directly — that's the pattern being migrated away from, so new/changed code should add or extend a `Query` module instead.

### Telemetry
Prefer `:telemetry` for cross-cutting concerns: emit `:telemetry` events for logging and for lifecycle / domain events, and attach handlers (or PubSub broadcasts) to react to them — rather than threading logging and side-effects directly through business logic. This keeps contexts focused on their core work and observable from the outside.

### Birding Data
[`Kjogvi.Birding`](./apps/kjogvi/lib/kjogvi/birding.ex) context, `Card`/`Location` models with privacy settings (`is_private`).

### Taxonomy
Use `Kjogvi.OrnithoRepo` via [ornithologue](./apps/ornithologue/). Mounted at `/taxonomy` with the `ornitho_web` macro.

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
| [apps/kjogvi/lib/kjogvi/birding.ex](./apps/kjogvi/lib/kjogvi/birding.ex) | Birding context & card logic |
| [apps/kjogvi/lib/kjogvi/geo/location.ex](./apps/kjogvi/lib/kjogvi/geo/location.ex) | Location model with privacy |

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
5. Mixing `Kjogvi.Repo` vs `Kjogvi.OrnithoRepo` — they're separate; migrations, rollback, and `ecto.dump`/`ecto.load` must be run against one repo at a time (`-r Kjogvi.Repo` or `-r Kjogvi.OrnithoRepo`)

## Notes for AI Agents

- Add and update tests for all code changes before committing
- Update module and function documentation when making changes
- Run `mix lint.fix` to auto-fix formatting + linting before commits
- Coordinate changes across `kjogvi` and `ornithologue` apps when adding features
- Examine existing LiveViews in `apps/kjogvi_web/lib/kjogvi_web/live/` for patterns
- When designing frontend, always make it responsive (check on smaller screen sizes)
- Be mindful of how it will present on text-based browsers (e.g. lynx) and for screen readers
- When creating a bunch of homogenous elements (e.g. filters), implement them using `<ul>` and `<li>`, even if they are not rendered visually as a list.
