defmodule Kjogvi.Jobs.Runtime.Bridge do
  @moduledoc """
  Bridges Oban job telemetry to the PubSub lifecycle broadcasts the task
  LiveViews follow.

  For every job whose worker is a `Kjogvi.Jobs.Runtime.ExclusiveWorker`
  (implements
  `pubsub_key/1`), the `[:oban, :job, :start | :stop | :exception]` telemetry
  events are rebroadcast as

      {:lifecycle, :start | :ok | :error, key, %Kjogvi.Util.AsyncResult{}}

  on the key's own topic (`Kjogvi.Util.PubSubTopic.for_key/1`) and on
  `lifecycle_topic/0`, which carries every key for dashboard-style observers.
  Jobs of plain Oban workers are ignored.

  Attached from `Kjogvi.Telemetry.setup/0`.
  """

  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  @lifecycle_topic "jobs:lifecycle"

  @doc """
  The PubSub topic carrying the lifecycle events of every exclusive job, for
  observers that don't know the keys in advance.
  """
  def lifecycle_topic, do: @lifecycle_topic

  def setup do
    :telemetry.attach_many(
      __MODULE__,
      [
        [:oban, :job, :start],
        [:oban, :job, :stop],
        [:oban, :job, :exception]
      ],
      &__MODULE__.handle_event/4,
      nil
    )
  end

  # A raise here would detach the handler for every future job, so anything
  # unrecognized falls through instead of crashing.
  def handle_event([:oban, :job, event], _measurements, %{job: job} = metadata, _config) do
    with {:ok, worker} <- Oban.Worker.from_string(job.worker),
         true <- function_exported?(worker, :pubsub_key, 1),
         {lifecycle_event, async_result} <- lifecycle(event, worker, metadata) do
      broadcast(worker.pubsub_key(job), lifecycle_event, async_result)
    end

    :ok
  end

  defp lifecycle(:start, worker, %{job: job}) do
    {:start, AsyncResult.loading(%{message: worker.start_message(job)})}
  end

  defp lifecycle(:stop, _worker, %{state: :success, result: result}) do
    {:ok, AsyncResult.ok(success_result(result))}
  end

  # `perform` returned {:cancel, reason} or {:discard, reason}.
  defp lifecycle(:stop, _worker, %{state: state, result: result})
       when state in [:cancelled, :discard] do
    {:error, AsyncResult.failed(%AsyncResult{}, stop_reason(result))}
  end

  # :snoozed — not a terminal transition, nothing to tell subscribers.
  defp lifecycle(:stop, _worker, _metadata), do: nil

  defp lifecycle(:exception, _worker, %{reason: reason}) do
    {:error, AsyncResult.failed(%AsyncResult{}, failure_reason(reason))}
  end

  defp success_result(:ok), do: nil
  defp success_result({:ok, value}), do: value
  defp success_result(other), do: other

  defp stop_reason({_tag, reason}), do: reason
  defp stop_reason(other), do: other

  # Unwrap Oban's exception wrappers so subscribers see the same reason terms
  # the old processor delivered: the term from an {:error, term} return,
  # `:timeout`, the exit reason of a crash, or the raised exception itself.
  defp failure_reason(%Oban.PerformError{reason: {:error, reason}}), do: reason
  defp failure_reason(%Oban.TimeoutError{}), do: :timeout
  defp failure_reason(%Oban.CrashError{reason: reason}), do: reason
  defp failure_reason(reason), do: reason

  defp broadcast(key, lifecycle_event, async_result) do
    message = {:lifecycle, lifecycle_event, key, async_result}

    Phoenix.PubSub.broadcast(Kjogvi.PubSub, PubSubTopic.for_key(key), message)
    Phoenix.PubSub.broadcast(Kjogvi.PubSub, @lifecycle_topic, message)
  end
end
