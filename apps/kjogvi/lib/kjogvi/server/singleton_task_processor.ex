defmodule Kjogvi.Server.SingletonTaskProcessor do
  use GenServer

  require Logger

  alias Kjogvi.Server.SingletonTaskProcessor
  alias Kjogvi.Util.AsyncResult

  def start_link(init_arg \\ []) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    {:ok, %{refs: %{}, statuses: %{}}}
  end

  def get_status(task_name, user_id) do
    GenServer.call(SingletonTaskProcessor, {:get_status, task_name, user_id})
  end

  def start_task(task_name, user_id, func) do
    GenServer.cast(SingletonTaskProcessor, {:start_task, task_name, user_id, func})
  end

  @impl true
  def handle_call({:get_status, task_name, user_id}, _from, %{statuses: statuses} = state) do
    {:reply, statuses[{task_name, user_id}], state}
  end

  @impl true
  def handle_cast({:start_task, task_name, user_id, func}, %{statuses: statuses} = state) do
    status = statuses[{task_name, user_id}]

    new_state =
      if is_nil(status) or !status.loading do
        %{ref: ref} =
          Task.Supervisor.async_nolink(Kjogvi.TaskSupervisor, fn -> func.(user_id) end)

        put_ref(
          state,
          ref,
          {task_name, user_id},
          AsyncResult.loading("Task #{task_name} started.")
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

    Logger.error("""
    #{inspect(__MODULE__)}: task #{inspect(Map.get(refs, ref))} returned a malformed \
    result: #{inspect(result)}. Task functions must return {:ok, data} or {:error, data}.
    """)

    {:noreply,
     state |> update_ref(ref, &AsyncResult.failed(&1, :malformed_result)) |> drop_ref(ref)}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state)
      when is_reference(ref) and reason != :normal do
    {:noreply, state |> update_ref(ref, &AsyncResult.failed(&1, reason)) |> drop_ref(ref)}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  # Tolerate genuine runtime noise the processor didn't model (e.g. a `:DOWN`
  # for an already-reaped ref): ignore it rather than crashing.
  def handle_info(_msg, state) do
    {:noreply, state}
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
