defmodule Kjogvi.Server.ExclusiveTaskProcessor do
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

  `start_task/3` is a no-op when a task for the same key is already loading, so
  concurrent or repeated requests (e.g. impatient double-clicks) cannot spawn a
  second run for that key. Once a task finishes, its status is retained under the
  key while the internal ref bookkeeping is dropped, so a later `start_task/3`
  for that key starts fresh.

  ## Shared, observable status

  Because the status lives in the processor rather than in any one caller, it
  outlives the process that started the task. This lets a newly mounted LiveView
  or component — opened in another tab, after a reconnect, or by a different part
  of the UI — call `get_status/1` and immediately see that the task is already
  running (or that it has finished, with its result/error), instead of offering
  to start it again. Combined with progress updates below, the new client also
  follows the rest of the task to completion.

  ## Progress updates

  The processor subscribes to the key's PubSub topic for the duration of a task,
  letting the task function push intermediate
  `AsyncResult`s by broadcasting `{:progress, key, async_result}`. These updates
  are merged into the tracked status. The `:progress` tag keeps them distinct
  from the internal task-result messages. Callers typically subscribe to the same
  topic to receive live progress, and use `get_status/1` to fetch the current
  status on mount/reconnect.

  ## Task contract

  The function passed to `start_task/3` receives the key and must return
  `{:ok, data}` or `{:error, data}`. Any other return value is treated as a
  failure (with reason `:malformed_result`) and logged, so a misbehaving task
  never leaves a status stuck in the loading state. Task crashes are caught via
  the monitor and recorded as failures with the exit reason.
  """
  use GenServer

  require Logger

  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  def start_link(init_arg \\ []) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{refs: %{}, statuses: %{}}}
  end

  # API

  def get_status(key) do
    GenServer.call(__MODULE__, {:get_status, key})
  end

  def start_task(key, start_message \\ "In progress...", func) do
    GenServer.cast(__MODULE__, {:start_task, key, start_message, func})
  end

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
  def handle_cast({:start_task, key, start_message, func}, %{statuses: statuses} = state) do
    status = statuses[key]

    new_state =
      if is_nil(status) or !status.loading do
        Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

        %{ref: ref} =
          Task.Supervisor.async_nolink(Kjogvi.TaskSupervisor, fn -> func.(key) end)

        put_ref(
          state,
          ref,
          key,
          AsyncResult.loading(%{message: start_message})
        )
      else
        state
      end

    {:noreply, new_state}
  end

  # Handle messages from processes

  @impl true
  def handle_info({ref, {:ok, data}}, state) when is_reference(ref) do
    # The task ended; we no longer need to monitor it.
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.unsubscribe(Kjogvi.PubSub, PubSubTopic.for_key(state.refs[ref]))

    # Drops the ref pointing to task signature, but the task signature -> result stays.
    {:noreply, state |> update_ref(ref, &AsyncResult.ok(&1, data)) |> drop_ref(ref)}
  end

  def handle_info({ref, {:error, data}}, state) when is_reference(ref) do
    # The task ended; we no longer need to monitor it.
    Process.demonitor(ref, [:flush])

    # Drops the ref pointing to task signature, but the task signature -> result stays.
    {:noreply, state |> update_ref(ref, &AsyncResult.failed(&1, data)) |> drop_ref(ref)}
  end

  # A task ref carrying anything other than {:ok, _} / {:error, _} means `func`
  # broke its contract. Treat it as a failure (so the status doesn't get stuck
  # on loading) and log it for the admin to investigate.
  def handle_info({ref, result}, %{refs: refs} = state)
      when is_reference(ref) and is_map_key(refs, ref) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.unsubscribe(Kjogvi.PubSub, PubSubTopic.for_key(state.refs[ref]))

    Logger.error("""
    #{inspect(__MODULE__)}: task #{inspect(Map.get(refs, ref))} returned a malformed \
    result: #{inspect(result)}. Task functions must return {:ok, data} or {:error, data}.
    """)

    {:noreply,
     state |> update_ref(ref, &AsyncResult.failed(&1, :malformed_result)) |> drop_ref(ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state)
      when is_reference(ref) and reason != :normal do
    Phoenix.PubSub.unsubscribe(Kjogvi.PubSub, PubSubTopic.for_key(state.refs[ref]))
    {:noreply, state |> update_ref(ref, &AsyncResult.failed(&1, reason)) |> drop_ref(ref)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # Progress updates broadcast by a running task on its key's topic. Tagged with
  # `:progress` so they can't be confused with task-result messages (which are
  # plain `{ref, _}` tuples). Ignored for keys we aren't currently tracking.
  def handle_info({:progress, key, async_result}, state) do
    if Map.has_key?(state.statuses, key) do
      {:noreply, %{state | statuses: Map.put(state.statuses, key, async_result)}}
    else
      {:noreply, state}
    end
  end

  # Registers a freshly started task: remember which key the ref belongs to
  # and record the initial status under that key.
  defp put_ref(%{refs: refs, statuses: statuses} = state, ref, key, async_result) do
    %{state | refs: Map.put(refs, ref, key), statuses: Map.put(statuses, key, async_result)}
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
end
