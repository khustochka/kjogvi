# Separate user settings into UserProfile and UserPreferences

## Context

Today all user settings live on the `users` table: identity fields (`nickname`, `display_name`), `default_book_signature`, and an `extras` jsonb embed holding eBird credentials and logbook settings. This mixes concerns and makes the `extras` embed a dumping ground. The goal is to split them into two dedicated 1:1 tables:

- **`user_profiles`** — public-facing "who I am" data: about, country, eBird profile link, website URL, birding-since year (avatar comes last, details TBD). `nickname` and `display_name` **stay in `users`** but remain edited on the Profile tab.
- **`user_preferences`** — behavioral settings: eBird sync credentials, logbook settings (both moved out of `extras`). `default_book_signature` **stays in `users`** but remains edited on the Preferences tab.

Migrations are **structure only — no data migration**. The `users.extras` column stays in the DB (data preserved for a possible later manual migration + column drop) but all code reading/writing it is removed, so existing users will re-enter their eBird/logbook settings.

Decisions made with user: country stored as **ISO 3166-1 alpha-2 code string**; extra profile fields approved: **website URL** and **birding since (year)**; profile fields are **edit-only** for now (no public display); **avatar is the last stage**, details to be discussed when we get there.

## Current state (key files)

- `apps/kjogvi/lib/kjogvi/accounts/user.ex` — schema with `embeds_one :extras`, `settings_changeset/3` (casts nickname, display_name, default_book_signature + `cast_embed(:extras)`), `ebird_configured_sync?/1`, `ebird_configured_async?/1`
- `apps/kjogvi/lib/kjogvi/accounts/user/extras.ex` + `extras/logbook_setting.ex` — the embed being dissolved
- `apps/kjogvi/lib/kjogvi/accounts.ex:351` — `update_user_settings/2` (calls `Kjogvi.Birding.Logbook.Cache.invalidate/1` after save)
- `apps/kjogvi_web/lib/kjogvi_web/live/my/settings/profile.ex` — Profile tab (nickname, display_name)
- `apps/kjogvi_web/lib/kjogvi_web/live/my/settings/preferences.ex` — Preferences tab (default_book_signature, eBird creds via nested `inputs_for`, logbook settings table with manual `user[extras][logbook_settings][i][...]` inputs)
- Readers of `extras`: `apps/kjogvi/lib/kjogvi/birding/logbook.ex:82,121` (logbook_settings), `apps/kjogvi/lib/kjogvi/ebird/web.ex:22-23` (ebird creds; `Client.preload_checklists/2` takes a plain `%{username:, password:}` map per `Login.credentials()`)
- Tests: `apps/kjogvi/test/kjogvi/accounts/user/extras_test.exs`, `apps/kjogvi_web/test/kjogvi_web/live/my/settings/preferences_test.exs`, `apps/kjogvi/test/kjogvi/birding/logbook_test.exs:17`, `apps/kjogvi_web/test/kjogvi_web/live/my/logbook/index_test.exs:37`
- Users are loaded without preloads everywhere (`get_user_by_session_token`, `get_user_by_nickname`, …) — the new assocs will be preloaded/fetched only where needed, not globally.

## Design

- `Kjogvi.Accounts.UserPreferences` (`user_preferences` table): `user_id` (FK, unique, `on_delete: :delete_all`), `ebird_username :string`, `ebird_password :string` (redacted), `logbook_settings` jsonb (`embeds_many`, column `:map` default `"[]"`), timestamps. `LogbookSetting` embed moves to `Kjogvi.Accounts.UserPreferences.LogbookSetting` (same fields).
- `Kjogvi.Accounts.UserProfile` (`user_profiles` table): `user_id` (FK, unique, `on_delete: :delete_all`), `about :text`, `country :string` (ISO alpha-2), `ebird_profile_url :string`, `website_url :string`, `birding_since :integer`, timestamps. Avatar column added later in the avatar stage.
- `User` gets `has_one :preferences` and `has_one :profile`. Rows are created **lazily** via `cast_assoc` on first settings save — no eager creation at registration, which also handles all existing users.
- `User.settings_changeset/3` is replaced by two tab-specific changesets:
  - `profile_settings_changeset/3`: casts `nickname`, `display_name` + `cast_assoc(:profile)`
  - `preferences_changeset/3`: casts `default_book_signature` + `cast_assoc(:preferences)`
  and `Accounts.update_user_settings/2` splits into `update_user_profile_settings/2` and `update_user_preferences/2` (the latter keeps the `Logbook.Cache.invalidate/1` call). Both preload the assoc before `cast_assoc`.
- Read helper `Accounts.get_user_preferences/1` → the user's row or a default `%UserPreferences{}` when absent, so readers never branch on nil.
- `ebird_configured_sync?/async?` move from `User` to `UserPreferences` (taking a preferences struct).
- Country select options built from common country-type locations (`Kjogvi.Geo`; `Location.iso_code` exists) — name + ISO code, no new dependency; stored value is just the ISO string.

## Stages (commit after each; stop for review per AGENTS.md)

### Stage 1 — UserPreferences backend
1. Migration `create_user_preferences` (structure above).
2. New `apps/kjogvi/lib/kjogvi/accounts/user_preferences.ex` with `changeset/2` (cast ebird_username/ebird_password, `cast_embed(:logbook_settings)`), move `LogbookSetting` to `accounts/user_preferences/logbook_setting.ex`, add `ebird_configured_sync?/1`, `ebird_configured_async?/1`.
3. `User`: add `has_one :preferences`; add `preferences_changeset/3`; keep old `settings_changeset` untouched for now (still used by both tabs).
4. `Accounts`: add `update_user_preferences/2` (preload + cast_assoc + cache invalidation) and `get_user_preferences/1`.
5. Tests: new `user_preferences_test.exs` (changeset, lazy row creation via update, default struct from `get_user_preferences/1`).

### Stage 2 — Switch consumers off extras, delete Extras
1. Preferences LiveView: form uses `preferences_changeset`; eBird inputs via `inputs_for @settings_form[:preferences]`; logbook table inputs renamed to `user[preferences][logbook_settings][i][...]`; mount/update flows load preferences via `Accounts.get_user_preferences/1` (assign preloaded user into scope after save as today).
2. Profile LiveView: switch to `profile_settings_changeset` / `update_user_profile_settings/2` (still only nickname + display_name at this stage).
3. `Logbook` (`logbook.ex:82,121`): read settings via `Accounts.get_user_preferences(subject_user).logbook_settings`.
4. `Ebird.Web` (`web.ex:22-23`): fetch preferences; guard with `UserPreferences.ebird_configured_async?/1`; pass `%{username: prefs.ebird_username, password: prefs.ebird_password}` to `Client.preload_checklists/2`.
5. Remove from `User`: `embeds_one :extras`, `settings_changeset/3`, `ebird_configured_*`; delete `user/extras.ex`, `user/extras/` and `extras_test.exs`. Remove `Accounts.update_user_settings/2`.
6. Update tests: `logbook_test.exs`, `my/logbook/index_test.exs`, `preferences_test.exs` (new param shape), profile settings tests.
7. `users.extras` column stays in DB, now unused.

### Stage 3 — UserProfile backend
1. Migration `create_user_profiles` (structure above, no avatar yet).
2. New `apps/kjogvi/lib/kjogvi/accounts/user_profile.ex`: `changeset/2` casting `about, country, ebird_profile_url, website_url, birding_since` with validations — `about` max length (~2000), `country` format `~r/^[A-Z]{2}$/`, URLs must be http(s), `birding_since` in `1900..current year`.
3. `User`: add `has_one :profile`; extend `profile_settings_changeset/3` with `cast_assoc(:profile)`; `Accounts.update_user_profile_settings/2` preloads `:profile`.
4. Tests for changeset + update.

### Stage 4 — Profile settings UI
1. Profile tab (`live/my/settings/profile.ex`): add fields under nickname/display_name via `inputs_for @settings_form[:profile]` — about (textarea), country (select from common country locations' name/iso_code, with prompt), eBird profile URL, website URL, birding since (number input). Responsive, no icons, follow existing form styling.
2. LiveView tests for editing/validation.

### Stage 5 — Avatar (design deferred)
Add avatar to `user_profiles` + upload UI. **Details (storage backend, Waffle vs. simpler, variants) to be discussed with the user when this stage is reached** — stop and discuss before implementing.

## Progress log

### Stage 1 — done (2026-07-08)
- Migration `20260708000000_create_user_preferences`: `user_preferences` table (`user_id` FK `on_delete: :delete_all` + unique index, `ebird` jsonb, `logbook_settings` jsonb default `[]`, timestamps). Migrated dev + test; `structure.sql` re-dumped. (Deviation, per user: eBird creds are a single `ebird` jsonb column with an inline `Ebird` embed — username/password — not two string columns.)
- New `Kjogvi.Accounts.UserPreferences` (`changeset/2`, `ebird_configured_sync?/1`, `ebird_configured_async?/1`) and `Kjogvi.Accounts.UserPreferences.LogbookSetting` (copy of the Extras embed; old one removed in Stage 2).
- `User`: `has_one :preferences, on_replace: :update` (`:update` needed — form params carry no id, so `cast_assoc` would hit `on_replace: :raise` when a row exists); `preferences_changeset/3` (default_book_signature + `cast_assoc(:preferences)`). `settings_changeset/3` untouched.
- `Accounts`: `update_user_preferences/2` (preload + cast_assoc + `Logbook.Cache.invalidate/1`), `get_user_preferences/1` (row or default struct).
- Tests: `accounts/user_preferences_test.exs` — changeset casts, configured checks, lazy row creation, update of existing row, default-struct read. `mix lint.fix` + full `mix test` green (675 + 539).
- Follow-up (per user): `UserPreferences.default/0` — users without a saved row (admin and regular alike) get logbook enabled for World (`location_id: nil, life: true, year: true`); `get_user_preferences/1` returns it instead of an empty struct.

## Verification (each stage)

- `mix lint.fix` and `mix test` before every commit (`MIX_ENV=test mix ecto.migrate` after each new migration).
- Stage 2: exercise the running app — save eBird creds + logbook checkboxes on `/my/settings/preferences`, confirm a `user_preferences` row is created lazily and the logbook page respects the settings.
- Stage 4: edit profile fields on `/my/settings/profile`, confirm validation errors (bad URL, bad year) and successful save.
- Commits: subject ends with a period, `Assisted-by:` trailer, in-the-moment approval before each commit.
