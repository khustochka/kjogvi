defmodule Kjogvi.Jobs.Bootstrap do
  @moduledoc """
  Seeds a fresh installation in one exclusive run: imports the default taxonomy
  (`Kjogvi.Settings.default_taxonomy_importer/0`), then restores common
  locations, then eBird locations.

  The order is required, not incidental: the eBird snapshot's `location_id`
  links point at common location ids, so common locations must land first.
  Running the steps inside a single `perform/1` — rather than chaining three
  jobs — is what guarantees it, and lets a failed step abort the rest.

  Steps are idempotent: an already-imported taxonomy is skipped, and both
  restores upsert.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, queue: :imports

  alias Kjogvi.Geo
  alias Kjogvi.Jobs
  alias Kjogvi.Settings

  @task_key :bootstrap

  @doc """
  The task key the bootstrap's status and lifecycle events are published under.
  """
  def task_key, do: @task_key

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(_job), do: @task_key

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def start_message(_job), do: "Bootstrapping taxonomy and locations..."

  # Taxonomy imports stream a large source file; the default 5 minutes is not
  # enough for all three steps.
  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(30)

  @impl Oban.Worker
  def perform(%Oban.Job{} = job) do
    with :ok <- import_taxonomy(job),
         :ok <- restore(job, :common_locations, "common locations"),
         :ok <- restore(job, :ebird_locations, "eBird locations") do
      {:ok, :bootstrapped}
    end
  end

  defp import_taxonomy(job) do
    importer = Settings.default_taxonomy_importer()
    Jobs.progress(job, %{message: "Importing #{importer.name()} taxonomy..."})

    # `process_import/1` raises on an existing book unless forced; skipping keeps
    # the bootstrap re-runnable without deleting taxa that are already there.
    if Ornitho.Finder.Book.exists?(importer.slug(), importer.version()) do
      :ok
    else
      case importer.process_import() do
        {:ok, _taxa_count} -> :ok
        {:error, reason} -> {:error, {:taxonomy_import_failed, reason}}
      end
    end
  end

  defp restore(job, dataset, label) do
    Jobs.progress(job, %{message: "Restoring #{label}..."})

    case Geo.Restore.run(dataset) do
      {:ok, _count} -> :ok
      {:error, reason} -> {:error, {dataset, reason}}
    end
  end
end
