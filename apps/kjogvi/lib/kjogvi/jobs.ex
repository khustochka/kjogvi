defmodule Kjogvi.Jobs do
  @moduledoc """
  Observable exclusive background jobs, on top of Oban.

  Workers built with `Kjogvi.Jobs.ExclusiveWorker` run at most one job per
  slot (worker + identifying args) at a time, and `Kjogvi.Jobs.Bridge`
  rebroadcasts their Oban telemetry as PubSub lifecycle events. This context
  answers "what is the slot's current status" from the `oban_jobs` table, so
  a freshly mounted LiveView can seed itself before following the live
  broadcasts.
  """

  alias Kjogvi.Repo
  alias Kjogvi.Util.AsyncResult

  @loading_states ~w(executing available scheduled retryable)

  @doc """
  Current status of the worker's exclusive slot as an `AsyncResult`.

  Reads the most relevant `oban_jobs` row for the worker + args: an in-flight
  row reports loading, otherwise the latest run reports how it ended. No row
  means the slot never ran (or its last run was pruned) — a blank result.
  """
  def status(worker, args \\ %{}) do
    worker
    |> Kjogvi.Jobs.Query.latest_for_slot(args)
    |> Repo.one(prefix: Oban.config().prefix)
    |> to_status(worker)
  end

  defp to_status(nil, _worker), do: %AsyncResult{}

  defp to_status(%Oban.Job{state: state} = job, worker) when state in @loading_states do
    AsyncResult.loading(%{message: worker.start_message(job)})
  end

  # Job rows don't record the perform result; a subscriber gets it from the
  # lifecycle broadcast. Folding results/progress from `meta` comes with
  # Stage 5 of the Oban migration.
  defp to_status(%Oban.Job{state: "completed"}, _worker), do: AsyncResult.ok(nil)

  defp to_status(%Oban.Job{state: "cancelled"}, _worker) do
    AsyncResult.failed(%AsyncResult{}, :cancelled)
  end

  defp to_status(%Oban.Job{state: "discarded", errors: errors}, _worker) do
    AsyncResult.failed(%AsyncResult{}, discard_reason(errors))
  end

  defp discard_reason([]), do: :discarded
  defp discard_reason(errors), do: errors |> List.last() |> Map.fetch!("error")
end
