defmodule Kjogvi.Imports.LogRecorder do
  @moduledoc """
  Keeps `Kjogvi.Imports.ImportLog` rows current from Oban job telemetry.

  Any job whose args carry an `"import_log_id"` (put there by the
  `Kjogvi.Imports` enqueue functions) has its log transitioned on the
  `[:oban, :job, :start | :stop | :exception]` events: `:running` on start,
  `:completed` with the summary on success, `:failed` with the reason on an
  error, crash, timeout, cancel, or discard. Recording from telemetry rather
  than inside `perform/1` means a run that dies without returning still gets
  its outcome written.

  A worker may export `completion_status/1`, receiving the summary from its
  `{:ok, summary}` return, to report `:completed_with_errors` for runs that
  finished but left rows unimported; without it every success is
  `:completed`.

  Attached from `Kjogvi.Telemetry.setup/0`. Jobs without the arg are ignored.
  """

  alias Kjogvi.Imports

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
    with %{args: %{"import_log_id" => import_log_id}} <- job do
      record(event, import_log_id, job, metadata)
    end

    :ok
  end

  defp record(:start, import_log_id, _job, _metadata) do
    Imports.log_started(import_log_id)
  end

  defp record(:stop, import_log_id, job, %{state: :success, result: result}) do
    summary = summary(result)
    Imports.log_completed(import_log_id, completion_status(job, summary), summary)
  end

  # `perform` returned {:cancel, reason} or {:discard, reason}.
  defp record(:stop, import_log_id, _job, %{state: state, result: result})
       when state in [:cancelled, :discard] do
    Imports.log_failed(import_log_id, error_text(stop_reason(result)))
  end

  # :snoozed — not a terminal transition.
  defp record(:stop, _import_log_id, _job, _metadata), do: :ok

  defp record(:exception, import_log_id, _job, %{reason: reason}) do
    Imports.log_failed(import_log_id, error_text(failure_reason(reason)))
  end

  defp summary({:ok, summary}) when is_map(summary), do: summary
  defp summary(_result), do: %{}

  defp completion_status(job, summary) do
    with {:ok, worker} <- Oban.Worker.from_string(job.worker),
         true <- function_exported?(worker, :completion_status, 1) do
      worker.completion_status(summary)
    else
      _ -> :completed
    end
  end

  defp stop_reason({_tag, reason}), do: reason
  defp stop_reason(other), do: other

  # Unwrap Oban's exception wrappers down to the underlying reason: the term
  # from an {:error, term} return, `:timeout`, the exit reason of a crash, or
  # the raised exception itself.
  defp failure_reason(%Oban.PerformError{reason: {:error, reason}}), do: reason
  defp failure_reason(%Oban.TimeoutError{}), do: :timeout
  defp failure_reason(%Oban.CrashError{reason: reason}), do: reason
  defp failure_reason(reason), do: reason

  defp error_text(reason) when is_binary(reason), do: reason
  defp error_text(%{__exception__: true} = exception), do: Exception.message(exception)
  defp error_text(reason), do: inspect(reason)
end
