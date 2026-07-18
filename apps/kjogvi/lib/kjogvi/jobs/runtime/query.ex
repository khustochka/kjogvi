defmodule Kjogvi.Jobs.Runtime.Query do
  @moduledoc """
  Queries over `oban_jobs` rows (`Oban.Job`).

  The table lives under Oban's configured schema prefix, not the default one,
  so run these with it: `Repo.one(query, prefix: Oban.config().prefix)`.
  """

  import Ecto.Query

  @in_flight_states ~w(executing available scheduled retryable)

  @doc """
  The single most relevant row for a worker's exclusive slot (worker + args):
  an in-flight job wins over finished ones, then recency decides.

  `args` are the slot-identifying args (the worker's `unique_keys`), matched
  by containment so a job carrying extra args still belongs to its slot.
  """
  def latest_for_slot(worker, args) do
    from j in Oban.Job,
      where: j.worker == ^Oban.Worker.to_string(worker),
      where: fragment("? @> ?", j.args, ^args),
      order_by: [desc: j.state in ^@in_flight_states, desc: j.id],
      limit: 1
  end

  @doc """
  Update query recording `progress` on the job's row under `meta["progress"]`,
  replacing the previous report.
  """
  def set_progress(job_id, progress) do
    from j in Oban.Job,
      where: j.id == ^job_id,
      update: [set: [meta: fragment("? || ?", j.meta, type(^%{progress: progress}, j.meta))]]
  end
end
