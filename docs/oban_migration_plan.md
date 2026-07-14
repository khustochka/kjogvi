# Replacing `ExclusiveTaskProcessor` with Oban

Plan to retire `Kjogvi.Server.ExclusiveTaskProcessor` (a single in-memory
`GenServer` task registry) in favour of [Oban](https://hexdocs.pm/oban)
(Free tier) + [Oban Web](https://hexdocs.pm/oban_web) (now free/OSS,
Apache-2.0, v2.11+).

## Why

`ExclusiveTaskProcessor` keeps all task state in a per-node in-memory map.
That is cheap and simple but has three limits we want gone:

1. **Not durable** — a deploy/restart mid-import loses the running task *and*
   its status.
2. **Not multi-node** — each node runs its own copy with its own state, so on
   a cluster (e.g. several Fly Machines) exclusivity silently breaks and
   `get_status/1` reads the wrong node's map.
3. **Bespoke surface** — ~420 lines of registry / timeout / TTL / monitor
   bookkeeping plus a hand-rolled admin dashboard to maintain.

Oban stores jobs as rows in Postgres (`oban_jobs`), which is our single shared
source of truth across every node. Uniqueness, "is it running", status, and
retention all become correct cluster-wide for free, and Oban Web replaces the
custom dashboard.

## What Oban gives us vs. what we keep building

| Concern | Today | With Oban (Free) |
|---|---|---|
| One run per key | in-memory guard in `handle_cast` | `unique:` on the worker (insert-time, Postgres advisory-locked) |
| Observable status | `get_status/1` reads in-memory map | query `oban_jobs` by worker + args → `state` column |
| Re-run once finished | drop ref, keep status | job leaves unique `states` → next insert allowed |
| Live push to LiveView | processor broadcasts `{:lifecycle,…}`/`{:progress,…}` | **we keep PubSub**, fired from a telemetry→PubSub bridge + inside workers |
| Timeout | per-task `Process.send_after` | `Worker.timeout/1` |
| Retries/backoff | none (single shot) | **none — kept single-shot** (`max_attempts: 1`) |
| Retention/TTL | periodic sweep | `Oban.Plugins.Pruner` |
| Admin dashboard | `Live.Admin.ExclusiveTasks.Index` | Oban Web (free) |

**Key fact:** Oban emits `:telemetry`, not PubSub. To keep our LiveViews'
live updates we bridge `[:oban, :job, :start|:stop|:exception]` telemetry to
`Phoenix.PubSub` on the *same topics and message shapes* we use today
(`{:lifecycle, event, key, ...}` / `{:progress, key, ...}`). That means the
consuming LiveViews/components change very little — only the *producer* of
those messages and the *seed-on-mount* (DB read instead of `get_status/1`).

## The tasks being migrated (4 keys, 2 shapes)

| Key today | Work | Args | Shape |
|---|---|---|---|
| `{:legacy_import, user_id}` | `Kjogvi.Legacy.Import.run/2` | `user_id` | per-user |
| `{:ebird_preload, user_id}` | eBird preload into store | `user_id` | per-user |
| `{:geo_restore, :common}` | `Kjogvi.Geo.Restore.run/1` | none | admin singleton |
| `{:geo_dump, :common}` | `Kjogvi.Geo.Dump.run/1` | none | admin singleton |

The work bodies are unrelated; what they share is the *wrapper*: run
exclusively per key, be observable, broadcast start/finish (and later
progress). That shared wrapper is what we factor into a behaviour/macro
(Stage 2), not a single generic worker.

---

## Design decisions

### Worker shape: shared base + thin per-task workers

We use **one worker module per task** (4 modules), each `use`-ing a shared
`Kjogvi.Jobs.ExclusiveWorker` macro that bakes in the common config and
helpers. The name is deliberate: this wrapper's whole job is to reproduce the
*exclusive, observable single-slot task* semantics of the old
`ExclusiveTaskProcessor` — not to be a generic base worker. This keeps
per-task uniqueness and per-task telemetry/dashboard rows clean and idiomatic,
while the DRY wrapper lives in one place. (A single generic key-dispatching
worker was rejected: it muddies uniqueness, telemetry, and the Web dashboard
grouping — the very things we're adopting Oban for.)

`use Kjogvi.Jobs.ExclusiveWorker` supplies:

- **`max_attempts: 1` — no retries** (see below);
- default `queue:` and a `unique:` spec keyed on the args that identify the
  slot (`[:user_id]` for per-user tasks; the singleton tasks are unique on an
  empty/constant key), across states `[:available, :scheduled, :executing]`;
- a `timeout/1` default (overridable);
- a `progress/2` helper (Stage 5) and a way to derive the **PubSub key** from a
  job, so the bridge and workers agree on topics.

### No retries — exclusive tasks run exactly once

These are one-shot exclusive tasks (imports, geo restore/dump). A silent Oban
retry would **double-run** the work, so the wrapper hard-codes
`max_attempts: 1`: a failed or crashed job goes straight to `discarded`
(→ `:error` lifecycle), never `retryable`. This matches today's single-shot
`ExclusiveTaskProcessor` behaviour. Consequently `retryable` is **omitted**
from the `unique` states — there is no retry state to guard against. (If a
future task ever wants retries, it can override `max_attempts` in its own
module rather than changing the shared default.)

Each concrete worker only provides its `perform/1` body and, where needed,
overrides queue/timeout.

### Deriving the PubSub key from a job

The LiveViews subscribe per key (e.g. `PubSubTopic.for_key({:legacy_import,
7})`). We need a total function `job -> key` so the telemetry bridge can
broadcast on the right per-key topic. Implement it as a callback on each worker
(e.g. `pubsub_key(%Oban.Job{args: %{"user_id" => id}}) -> {:legacy_import,
id}`), surfaced through the shared macro. The bridge looks the worker up by
`job.worker`, calls its `pubsub_key/1`, and broadcasts.

### Seeding status on mount (replaces `get_status/1`)

A small query module — `Kjogvi.Jobs.Query` (or `Kjogvi.Jobs` context fronting
it) — answers "current status for this key" by selecting the most relevant
`oban_jobs` row for a worker + args and mapping its `state` (+ later
`meta`/result) to the `%AsyncResult{}` the LiveViews already render. Ordering:
prefer an in-flight row (`executing`/`available`/`retryable`/`scheduled`),
else the latest terminal row (`completed`/`discarded`/`cancelled`). Per
AGENTS.md this lives in a `Query` module, not in a context that
`import Ecto.Query`s.

### Retention caveat (finished results)

The Pruner eventually deletes terminal jobs, so a finished result is not
retained forever (today's TTL keeps it ~1h; that behaviour is roughly matched
by prune settings). If any screen must show a finished result *beyond* the
prune window, that fact belongs in a domain record, not the job row. For the
import pages this is not needed — they care about running / just-finished.

---

## Stages

Implement the **harness first** (Stages 1–4), get it green with the existing
LiveViews, then **switch the jobs over** and delete the old processor
(Stages 3–6 do the switch task by task). Rich progress is deliberately last
(Stage 5) so the core migration lands without it.

Per the repo workflow: **stop after each stage for review**; run `mix lint.fix`
and `mix test` before committing each stage.

### Stage 1 — Add Oban + Oban Web, no jobs yet

- Add deps: `{:oban, "~> 2.19"}` (kjogvi), `{:oban_web, "~> 2.11"}`
  (kjogvi_web). Confirm exact current versions at implementation time.
- Migration: `Oban.Migration.up/1` creating the `oban_jobs` table in
  `Kjogvi.Repo` (main repo; **not** the `ornithologue` prefix).
- Config `:kjogvi, Oban`: repo `Kjogvi.Repo`, queues (e.g. `imports: 2,
  geo: 1`), plugins `[Pruner]`. In `config/test.exs` set `testing: :manual`
  (or `:inline`) so tests don't spin real queues.
- Supervision: add `{Oban, Application.fetch_env!(:kjogvi, Oban)}` to
  `Kjogvi.Application` children (alongside `Repo`/`PubSub`). Leave
  `ExclusiveTaskProcessor` in place for now — both coexist.
- Router: mount `oban_dashboard "/oban"` inside the existing `/admin` scope
  (it already imports `Phoenix.LiveDashboard.Router` and mounts
  `live_dashboard`, so this is the same pattern, guarded by `:require_admin`).
- **Verify:** app boots, `/admin/oban` renders an empty dashboard, existing
  suite still green.

### Stage 2 — The harness: `Kjogvi.Jobs.Worker` behaviour + telemetry→PubSub bridge + status query

No task is switched yet; this builds the reusable wrapper and proves it with a
throwaway/test worker.

- `Kjogvi.Jobs.ExclusiveWorker` macro (`use Oban.Worker` under the hood)
  providing: `max_attempts: 1` (no retries), shared `unique`/`queue`/`timeout`
  defaults, a `pubsub_key/1` callback, and a place for the future `progress/2`
  helper.
- `Kjogvi.Jobs.Notifier` (or `.Bridge`): attaches to `[:oban, :job, :start]`,
  `[:oban, :job, :stop]`, `[:oban, :job, :exception]`; for jobs whose worker
  implements `pubsub_key/1`, broadcasts the existing message shapes on both the
  per-key topic (`PubSubTopic.for_key/1`) and a global topic (replacing
  `lifecycle_topic/0`) as `{:lifecycle, :start|:ok|:error, key, async_result}`.
  Map job outcome → `%AsyncResult{}` here (start=loading, stop=ok, exception=
  failed). Attach it from the supervision tree / a telemetry setup module
  (mirroring `Kjogvi.Telemetry.setup/0`).
- `Kjogvi.Jobs.Query` + a thin `Kjogvi.Jobs` context function
  `status(worker, args) :: %AsyncResult{}` selecting the relevant `oban_jobs`
  row and mapping `state` → AsyncResult (no result/meta yet — Stage 5).
- **Tests:** enqueue a trivial worker with `Oban.Testing`; assert
  `pubsub_key/1`, that the bridge broadcasts the right `{:lifecycle,…}` on the
  right topic, and that `Jobs.status/2` reports loading/ok/failed. Use
  `Oban.Testing` helpers (`with_testing_mode/2`, `assert_enqueued`,
  `Oban.drain_queue/2`).
- **Verify:** trivial worker run end-to-end drives a `{:lifecycle,…}` broadcast
  a subscribed test process receives.

### Stage 3 — Switch the two admin-singleton tasks (`geo_restore`, `geo_dump`)

Start with the simpler, argument-free tasks and the single LiveView that hosts
them (`Live.Admin.Imports.Locations.Index`).

- `Kjogvi.Jobs.GeoRestore` / `Kjogvi.Jobs.GeoDump` workers wrapping
  `Geo.Restore.run/1` / `Geo.Dump.run/1`; `pubsub_key/1` returns
  `{:geo_restore, :common}` / `{:geo_dump, :common}`.
- Update `Live.Admin.Imports.Locations.Index`:
  - `start_restore` / `start_dump` → `Oban.insert/1` (handle the
    `{:ok, conflict}`/`unique` case = "already running", so the button state
    stays honest).
  - mount seed → `Kjogvi.Jobs.status/2` instead of
    `ExclusiveTaskProcessor.get_status/1`.
  - keep the `handle_info({:lifecycle, event, key, async_result}, …)` clauses
    — same messages, now from the bridge. Keep the
    `maybe_refresh_dataset_state(:ok)` behaviour.
- Update `apps/kjogvi_web/.../live/admin/imports/locations/index_test.exs`.
- **Verify (`/run` or manual):** click Restore/Dump, watch status go
  loading→ok, second click while running is a no-op, dataset counts refresh on
  completion.

### Stage 4 — Switch the two per-user tasks (`legacy_import`, `ebird_preload`)

- `Kjogvi.Jobs.LegacyImport` / `Kjogvi.Jobs.EbirdPreload` workers; args carry
  `user_id`; `pubsub_key/1` → `{:legacy_import, id}` / `{:ebird_preload, id}`;
  `unique` keyed on `[:user_id]`.
- Update `Live.My.Imports.Legacy` and `Live.My.Imports.Ebird`:
  - `start_import` → `Oban.insert/1`.
  - `subscribe_once` seed → `Kjogvi.Jobs.status/2`.
  - keep the `on_mount(:attach)` progress/lifecycle hooks and `send_update`
    plumbing — message shapes unchanged.
  - preserve the Ebird `lifecycle: :ok` branch that refreshes preload data
    from the store.
- Update the corresponding tests
  (`live/my/imports/index_test.exs`, ebird/legacy specs).
- **Verify:** a user kicks off legacy + eBird imports; status shared across
  tabs; double-click guarded; success/failure flash correct.

### Stage 5 — Rich progress (deferred until here)

Now add mid-task progress on top of the working migration.

- `Kjogvi.Jobs.ExclusiveWorker` gains `progress(job, async_result)`:
  1. **durable** — update `job.meta["progress"]` (throttled, e.g. ≤1/sec or
     per batch) so a fresh page load / other node sees it;
  2. **live** — `Phoenix.PubSub.broadcast(... {:progress, key, async_result})`
     on the per-key topic (exactly the message the components already handle).
- Wire the two importers to call `progress/2` where they currently emit
  `[:kjogvi, :legacy, :import, _, :progress]` telemetry / `broadcast_key`
  (see `apps/kjogvi/lib/kjogvi/legacy/import.ex`). `geo_restore`/`geo_dump`
  emit no progress today — leave as-is.
- Extend `Kjogvi.Jobs.status/2` to fold `meta["progress"]` into the loading
  `%AsyncResult{}` on mount, so a mid-run page load shows current progress, not
  just "loading".
- Oban Web shows the job + its meta; per-task LiveViews show the rich message.
- **Tests:** worker reports progress → `meta` updated *and* `{:progress,…}`
  broadcast; `status/2` reflects in-flight progress.

### Stage 6 — Remove `ExclusiveTaskProcessor` and its dashboard

Once all four tasks run on Oban and are verified:

- Delete `Kjogvi.Server.ExclusiveTaskProcessor` + its test; remove it from
  `Kjogvi.Application` children.
- Delete `Live.Admin.ExclusiveTasks.Index` + test; remove its route
  (`/admin/exclusive-tasks`) — Oban Web (`/admin/oban`) replaces it. Update any
  admin nav link.
- Decide `Kjogvi.TaskSupervisor`'s fate: keep only if something else uses it
  (grep first); otherwise remove.
- Grep for stragglers: `ExclusiveTaskProcessor`, `lifecycle_topic`,
  `list_statuses`, `get_status`, `AsyncResult` seams that were processor-only.
- Update `AGENTS.md` (the exclusive-tasks / `/admin` mentions) and remove
  `PubSubTopic`/`AsyncResult` docs referencing the processor if now stale.
- **Verify:** full suite green; `mix lint`; `/admin/oban` is the sole task
  dashboard; imports still work end-to-end.

---

## Potential improvements (not part of the core migration)

Recovering a **stuck `executing` job** — one whose node hard-crashed
(SIGKILL/OOM/machine death) mid-run, leaving its row wedged in `executing`.
Because `executing` is in the `unique` guard states, the exclusive slot stays
held by the ghost and the user/admin sees "already running" with no way to
start a fresh run. Two independent, Free recovery paths, either or both of
which we can add later:

- **Automatic — `Oban.Plugins.Lifeline`.** The only built-in plugin that
  rescues stuck `executing` jobs: it detects them via stale producer
  heartbeats (the owning node stopped checking in) and, after `:rescue_after`
  (default 60 min; tune down, e.g. 15 min, for these tasks), moves them out of
  `executing`. With our `max_attempts: 1` a rescued orphan becomes `discarded`,
  not re-run — the correct, safe behaviour (never silently double-run an
  import). Without this plugin a crashed job stays `executing` **forever**;
  the Pruner does *not* help (it only deletes terminal jobs). This is the
  safety net for when no admin is watching.

- **Manual — admin cancel.** `Oban.cancel_job/1` moves the job to `cancelled`
  (terminal), which leaves the `unique` states and immediately frees the slot
  for a fresh run. **Oban Web already provides this cancel button** under our
  `/admin` (`:require_admin`) pipeline, so it's zero custom code — the
  immediate, human recovery path. Optionally, the import page could show a
  "looks stuck" hint by checking producer-heartbeat staleness for the
  `executing` job, if we ever want it inline rather than in the dashboard.

## Open questions / things to confirm at implementation time

- **Exact dep versions** for `oban` and `oban_web` (pin current stable).
- **Queue layout & concurrency** — proposed `imports: 2, geo: 1`; tune later.
  Note: on multiple nodes, insert-time `unique` still prevents a *second
  enqueue* while one runs, which is what we want; true "only one executing
  cluster-wide" (global concurrency) is an **Oban Pro** feature — out of scope,
  Free is sufficient here.
- **Test mode** — `:manual` vs `:inline` per suite; the LiveView tests that
  assert lifecycle broadcasts need the bridge to fire, so drive jobs with
  `Oban.drain_queue/2` or `:inline`.
- **Prune window** vs. how long a finished result should stay visible on the
  import pages.

## References

- Oban Web is free/OSS since Jan 2025 (Apache-2.0, v2.11+ on Hex):
  <https://oban.pro/articles/oss-web-and-new-oban>
- Current callers to migrate:
  - `apps/kjogvi_web/lib/kjogvi_web/live/my/imports/legacy.ex`
  - `apps/kjogvi_web/lib/kjogvi_web/live/my/imports/ebird.ex`
  - `apps/kjogvi_web/lib/kjogvi_web/live/admin/imports/locations/index.ex`
  - `apps/kjogvi_web/lib/kjogvi_web/live/admin/exclusive_tasks/index.ex` (to delete)
- Being replaced:
  `apps/kjogvi/lib/kjogvi/server/exclusive_task_processor.ex`
