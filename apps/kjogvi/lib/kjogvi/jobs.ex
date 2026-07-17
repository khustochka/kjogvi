defmodule Kjogvi.Jobs do
  @moduledoc """
  Observable exclusive background jobs, on top of Oban.

  Workers built with `Kjogvi.Jobs.ExclusiveWorker` run at most one job per
  slot (worker + identifying args) at a time, and `Kjogvi.Jobs.Bridge`
  rebroadcasts their Oban telemetry as PubSub lifecycle events. This context
  answers "what is the slot's current status" from the `oban_jobs` table, so
  a freshly mounted LiveView can seed itself before following the live
  broadcasts, and carries mid-run progress reports (`progress/2`).
  """

  alias Kjogvi.Repo
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

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

  @doc """
  Reports mid-run progress to the task's followers.

  For an `%Oban.Job{}` the report is durable as well as live: it is recorded
  on the job row's `meta["progress"]` — where `status/2` and Oban Web pick it
  up — and broadcast as `{:progress, key, progress}` on the task key's PubSub
  topic. For a bare task key (a run outside a job, e.g. from IEx) it is only
  broadcast. Callers report at most once per batch of work, which bounds the
  write rate.
  """
  def progress(%Oban.Job{} = job, %{message: _} = progress) do
    {:ok, worker} = Oban.Worker.from_string(job.worker)

    job.id
    |> Kjogvi.Jobs.Query.set_progress(progress)
    |> Repo.update_all([], prefix: Oban.config().prefix)

    progress(worker.pubsub_key(job), progress)
  end

  def progress(key, %{message: _} = progress) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:progress, key, progress}
    )
  end

  defp to_status(nil, _worker), do: %AsyncResult{}

  defp to_status(%Oban.Job{state: state} = job, worker) when state in @loading_states do
    AsyncResult.loading(loading_state(job, worker))
  end

  # Job rows don't record the perform result; a subscriber gets it from the
  # lifecycle broadcast.
  defp to_status(%Oban.Job{state: "completed"}, _worker), do: AsyncResult.ok(nil)

  defp to_status(%Oban.Job{state: "cancelled"}, _worker) do
    AsyncResult.failed(%AsyncResult{}, :cancelled)
  end

  defp to_status(%Oban.Job{state: "discarded", errors: errors}, _worker) do
    AsyncResult.failed(%AsyncResult{}, discard_reason(errors))
  end

  defp discard_reason([]), do: :discarded
  defp discard_reason(errors), do: errors |> List.last() |> Map.fetch!("error")

  # `meta` round-trips through JSON, hence the string keys.
  defp loading_state(%Oban.Job{meta: %{"progress" => %{"message" => message}}}, _worker) do
    %{message: message}
  end

  defp loading_state(job, worker), do: %{message: worker.start_message(job)}
end
