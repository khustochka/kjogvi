defmodule Kjogvi.Server.ExclusiveTaskProcessor do
  # Default `:timeout` for `start_task/3,4`, in milliseconds. Defined before the
  # moduledoc so it can be interpolated into the docs.
  @default_timeout 5 * 60 * 1000

  # How long a finished (ok/failed) status is retained before the periodic sweep
  # evicts it, in milliseconds, and how often that sweep runs. Loading statuses
  # are never swept.
  @default_ttl 60 * 60 * 1000
  @default_sweep_interval 30 * 60 * 1000

  @moduledoc """
  Runs long-running background tasks while guaranteeing that, per key, only one
  task runs at a time.

  Each task is identified by an arbitrary key (typically a tuple such as
  `{:legacy_import, user_id}`). The key acts as an exclusive slot: while a task
  for a given key is in flight, no other task for that same key can be started.
  Tasks under different keys run concurrently and independently.

  This is implemented as a single named `GenServer` that owns a registry of
  tasks keyed by that term. Each task runs under `Kjogvi.TaskSupervisor` via
  `Task.Supervisor.async_nolink/2`, and its status is tracked as a
  `Kjogvi.Util.AsyncResult` so callers can render loading / ok / failed states.

  ## One task per key

  `start_task/3,4` is a no-op when a task for the same key is already loading, so
  concurrent or repeated requests (e.g. impatient double-clicks) cannot spawn a
  second run for that key. Once a task finishes, its status is retained under the
  key while the internal ref bookkeeping is dropped, so a later `start_task/3,4`
  for that key starts fresh.

  ## Shared, observable status

  Because the status lives in the processor rather than in any one caller, it
  outlives the process that started the task. This lets a newly mounted LiveView
  or component — opened in another tab, after a reconnect, or by a different part
  of the UI — call `get_status/1,2` and immediately see that the task is already
  running (or that it has finished, with its result/error), instead of offering
  to start it again. Combined with progress updates below, the new client also
  follows the rest of the task to completion.

  ## Progress updates

  The processor subscribes to the key's PubSub topic for the duration of a task,
  letting the task function push intermediate
  `AsyncResult`s by broadcasting `{:progress, key, async_result}`. These updates
  are merged into the tracked status. The `:progress` tag keeps them distinct
  from the internal task-result messages. Callers typically subscribe to the same
  topic to receive live progress, and use `get_status/1,2` to fetch the current
  status on mount/reconnect.

  ## Lifecycle events

  In addition to the task-driven `:progress` updates, the processor itself
  broadcasts lifecycle events to the same key topic as the tracked status
  transitions:

    * `{:lifecycle, :start, key, async_result}` — when a task is started
    * `{:lifecycle, :ok, key, async_result}` — when it finishes `{:ok, _}`
    * `{:lifecycle, :error, key, async_result}` — when it finishes `{:error, _}`,
      returns a malformed result, or crashes

  The `async_result` is the `AsyncResult` exactly as it is stored under the key,
  so a subscriber can assign it directly without calling `get_status/1,2`. This
  lets callers who subscribed to the topic learn about start/completion without
  polling, complementing the mid-task `:progress` updates.

  ## Task contract

  The function passed to `start_task/3,4` receives the key and must return
  `{:ok, data}` or `{:error, data}`. Any other return value is treated as a
  failure (with reason `:malformed_result`) and logged, so a misbehaving task
  never leaves a status stuck in the loading state. Task crashes are caught via
  the monitor and recorded as failures with the exit reason.

  ## Timeout

  `start_task/3,4` accepts a `:timeout` option (milliseconds, or `:infinity` to
  disable). It defaults to `#{div(@default_timeout, 60_000)} minutes`. When a task
  runs longer than its timeout, the processor shuts it down via
  `Kjogvi.TaskSupervisor` and records a failure with reason `:timeout`,
  broadcasting the usual `{:lifecycle, :error, key, _}` event. This guarantees a
  runaway task can't hold its key's exclusive slot forever.

  ## Retention and cleanup

  A finished status is retained under its key so late-arriving clients can still
  observe the last result (see "Shared, observable status"). To stop these from
  accumulating forever, each terminal transition stamps the key with a finish
  time, and a periodic sweep evicts any finished status older than `:ttl`
  milliseconds (default #{div(@default_ttl, 60_000)} minutes; `:infinity` disables
  it). The sweep runs every `:sweep_interval` milliseconds. Only finished statuses are
  eligible: a loading task is never swept, and an evicted key behaves exactly
  like one that was never run (`get_status/1,2` returns a blank result and the
  next `start_task/3,4` runs fresh). `:ttl` and `:sweep_interval` can be
  overridden via `start_link/1`; the application supervisor starts the singleton
  with the defaults above.
  """
  use GenServer

  require Logger

  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  def start_link(init_arg \\ []) do
    {name, init_arg} = Keyword.pop(init_arg, :name, __MODULE__)
    GenServer.start_link(__MODULE__, init_arg, name: name)
  end

  @impl true
  def init(init_arg) do
    ttl = Keyword.get(init_arg, :ttl, @default_ttl)
    sweep_interval = Keyword.get(init_arg, :sweep_interval, @default_sweep_interval)

    schedule_sweep(sweep_interval)

    {:ok,
     %{
       refs: %{},
       statuses: %{},
       timers: %{},
       finished_at: %{},
       ttl: ttl,
       sweep_interval: sweep_interval
     }}
  end

  # API
  #
  # `opts` accepts `:server` (defaults to the singleton named process started by
  # the application supervisor; tests pass their own isolated instance),
  # `:message` (the initial loading status, shown until the task reports
  # otherwise), and `:timeout` (milliseconds before the task is shut down and
  # recorded as a `:timeout` failure, or `:infinity` to disable; defaults to
  # `@default_timeout`).

  def get_status(key, opts \\ []) do
    GenServer.call(server(opts), {:get_status, key})
  end

  def start_task(key, func, opts \\ []) when is_function(func, 1) do
    message = Keyword.get(opts, :message, "In progress...")
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.cast(server(opts), {:start_task, key, message, func, timeout})
  end

  defp server(opts), do: Keyword.get(opts, :server, __MODULE__)

  # Callbacks

  @impl true
  def handle_call({:get_status, key}, _from, %{statuses: statuses} = state) do
    {
      :reply,
      statuses[key] || %AsyncResult{},
      state
    }
  end

  @impl true
  def handle_cast({:start_task, key, start_message, func, timeout}, %{statuses: statuses} = state) do
    status = statuses[key]

    new_state =
      if is_nil(status) or !status.loading do
        Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

        %{ref: ref, pid: pid} =
          Task.Supervisor.async_nolink(Kjogvi.TaskSupervisor, fn -> func.(key) end)

        state
        |> put_ref(ref, key, AsyncResult.loading(%{message: start_message}))
        |> schedule_timeout(ref, pid, timeout)
        |> broadcast_lifecycle(:start, key)
      else
        state
      end

    {:noreply, new_state}
  end

  # Handle messages from processes

  @impl true
  def handle_info({ref, {:ok, data}}, state) when is_reference(ref) do
    {:noreply, finish_task(state, ref, :ok, &AsyncResult.ok(&1, data))}
  end

  def handle_info({ref, {:error, data}}, state) when is_reference(ref) do
    {:noreply, finish_task(state, ref, :error, &AsyncResult.failed(&1, data))}
  end

  # A task ref carrying anything other than {:ok, _} / {:error, _} means `func`
  # broke its contract. Treat it as a failure (so the status doesn't get stuck
  # on loading) and log it for the admin to investigate.
  def handle_info({ref, result}, %{refs: refs} = state)
      when is_reference(ref) and is_map_key(refs, ref) do
    Logger.error("""
    #{inspect(__MODULE__)}: task #{inspect(Map.get(refs, ref))} returned a malformed \
    result: #{inspect(result)}. Task functions must return {:ok, data} or {:error, data}.
    """)

    {:noreply, finish_task(state, ref, :error, &AsyncResult.failed(&1, :malformed_result))}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{refs: refs} = state)
      when is_reference(ref) and is_map_key(refs, ref) and reason != :normal do
    {:noreply, finish_task(state, ref, :error, &AsyncResult.failed(&1, reason))}
  end

  # An untracked `:DOWN` — a `:normal` exit (its result was already handled), or
  # the shutdown of a task we just timed out and finished. Nothing left to do.
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # Periodic retention sweep. Evicts every finished status older than `:ttl`,
  # then reschedules itself. `:infinity` ttl keeps the loop running (cheap) but
  # never evicts, so retention can be re-enabled without restarting the process.
  def handle_info(:sweep, state) do
    schedule_sweep(state.sweep_interval)
    {:noreply, sweep_expired(state)}
  end

  # The task ran past its `:timeout`. Shut it down through the supervisor (the
  # resulting `:DOWN` is then ignored, since `finish_task` drops the ref) and
  # record the timeout as a failure. A stale timer for an already-finished task
  # carries a ref we no longer track, so it's ignored.
  def handle_info({:timeout, ref}, %{refs: refs, timers: timers} = state)
      when is_map_key(refs, ref) do
    {_timer_ref, pid} = Map.fetch!(timers, ref)
    Task.Supervisor.terminate_child(Kjogvi.TaskSupervisor, pid)
    {:noreply, finish_task(state, ref, :error, &AsyncResult.failed(&1, :timeout))}
  end

  def handle_info({:timeout, _ref}, state) do
    {:noreply, state}
  end

  # The processor's own `:start` lifecycle broadcast is delivered back to it,
  # since it is still subscribed to the key topic at that point. It's purely for
  # external subscribers, so the processor ignores it.
  def handle_info({:lifecycle, _event, _key, _async_result}, state) do
    {:noreply, state}
  end

  # Progress updates broadcast by a running task on its key's topic. Tagged with
  # `:progress` so they can't be confused with task-result messages (which are
  # plain `{ref, _}` tuples). Ignored for keys we aren't currently tracking.
  def handle_info({:progress, key, status}, state) do
    current_result = Map.get(state.statuses, key)

    if current_result do
      {:noreply,
       %{
         state
         | statuses: Map.put(state.statuses, key, AsyncResult.loading(current_result, status))
       }}
    else
      {:noreply, state}
    end
  end

  # Teardown shared by every terminal clause: stop monitoring the task, drop its
  # PubSub subscription, transition its status via `fun`, and forget the ref. The
  # key is looked up (via `update_ref`/`unsubscribe`) before `drop_ref` removes
  # it, so the topic is always derived from the real key rather than `nil`.
  # `Process.demonitor(ref, [:flush])` is safe even when the monitor already
  # fired (the `:DOWN` clause), so all clauses can share this path.
  defp finish_task(state, ref, event, fun) do
    key = Map.fetch!(state.refs, ref)

    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.unsubscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

    # Drops the ref pointing to task signature, but the task signature -> result
    # stays. The finish time is stamped so the periodic sweep can later evict it.
    state
    |> cancel_timeout(ref)
    |> update_ref(ref, fun)
    |> drop_ref(ref)
    |> stamp_finished(key)
    |> broadcast_lifecycle(event, key)
  end

  # Arms a per-task timer that fires `{:timeout, ref}` after `timeout`
  # milliseconds. `:infinity` disables the timer. The timer ref is kept alongside
  # the task pid so the timeout handler can shut the task down and `finish_task`
  # can cancel a still-pending timer.
  defp schedule_timeout(state, _ref, _pid, :infinity), do: state

  defp schedule_timeout(%{timers: timers} = state, ref, pid, timeout) do
    timer_ref = Process.send_after(self(), {:timeout, ref}, timeout)
    %{state | timers: Map.put(timers, ref, {timer_ref, pid})}
  end

  # Cancels and forgets a task's timer when it finishes (for any reason). Safe
  # when no timer was armed (`:infinity`) or it already fired.
  defp cancel_timeout(%{timers: timers} = state, ref) do
    case Map.pop(timers, ref) do
      {nil, _timers} ->
        state

      {{timer_ref, _pid}, timers} ->
        Process.cancel_timer(timer_ref)
        %{state | timers: timers}
    end
  end

  # Registers a freshly started task: remember which key the ref belongs to
  # and record the initial status under that key. Any prior finish stamp for the
  # key is cleared, so a restarted (now-loading) task can't be swept.
  defp put_ref(
         %{refs: refs, statuses: statuses, finished_at: finished_at} = state,
         ref,
         key,
         async_result
       ) do
    %{
      state
      | refs: Map.put(refs, ref, key),
        statuses: Map.put(statuses, key, async_result),
        finished_at: Map.delete(finished_at, key)
    }
  end

  # Transitions the status for a task, looked up by its ref. `fun` receives the
  # current `AsyncResult` (the loading one recorded at start) and returns the
  # updated one. The ref and its status are invariants set together at start, so
  # a missing one means a bug — fail fast rather than mask it.
  defp update_ref(%{refs: refs, statuses: statuses} = state, ref, fun) do
    key = Map.fetch!(refs, ref)
    current = Map.fetch!(statuses, key)
    %{state | statuses: Map.put(statuses, key, fun.(current))}
  end

  # Forgets a finished task's ref so it doesn't leak. The status stays in place.
  defp drop_ref(%{refs: refs} = state, ref) do
    %{state | refs: Map.delete(refs, ref)}
  end

  # Announces a status transition on the key's topic, carrying the `AsyncResult`
  # exactly as stored, so subscribers can assign it without calling get_status/2.
  # Returns the state unchanged for pipelining.
  defp broadcast_lifecycle(%{statuses: statuses} = state, event, key) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:lifecycle, event, key, Map.fetch!(statuses, key)}
    )

    state
  end

  # Records when a key's task finished, so the sweep can age it out. Uses
  # monotonic time (immune to wall-clock adjustments) in milliseconds.
  defp stamp_finished(%{finished_at: finished_at} = state, key) do
    %{state | finished_at: Map.put(finished_at, key, System.monotonic_time(:millisecond))}
  end

  # Arms the next retention sweep.
  defp schedule_sweep(sweep_interval) do
    Process.send_after(self(), :sweep, sweep_interval)
  end

  # Drops every finished status whose age exceeds `:ttl`. A still-loading key has
  # no finish stamp, so it is never eligible. `:infinity` retains everything.
  # `finished_at` and `:ttl` are both in milliseconds, so they compare directly.
  defp sweep_expired(%{ttl: :infinity} = state), do: state

  defp sweep_expired(%{finished_at: finished_at, statuses: statuses, ttl: ttl} = state) do
    now = System.monotonic_time(:millisecond)

    expired =
      for {key, at} <- finished_at, now - at >= ttl, do: key

    %{
      state
      | statuses: Map.drop(statuses, expired),
        finished_at: Map.drop(finished_at, expired)
    }
  end
end
