defmodule Kjogvi.Imports do
  @moduledoc """
  User-facing data imports: enqueuing import jobs and recording their runs.

  Each run is tracked as a `Kjogvi.Imports.ImportLog`, created together with
  the Oban job and carried in its args as `import_log_id`;
  `Kjogvi.Imports.LogRecorder` moves it through its lifecycle from the job's
  telemetry events. The uploaded source files themselves are handled by
  `Kjogvi.Imports.Upload`.
  """

  alias Kjogvi.Imports.ImportLog
  alias Kjogvi.Repo

  @doc """
  Creates an `ImportLog` and enqueues the eBird import job for it, in one
  transaction.

  The job is exclusive per user: enqueuing while a run is in flight returns
  `{:error, :already_running}` (rolling the log back) and leaves the running
  job untouched.
  """
  def enqueue_ebird_import(user, upload_key) do
    Repo.transact(fn ->
      {:ok, import_log} =
        %{source: :ebird, user_id: user.id}
        |> ImportLog.create_changeset()
        |> Repo.insert()

      job_args = %{user_id: user.id, upload_key: upload_key, import_log_id: import_log.id}

      case Oban.insert(Kjogvi.Jobs.Ebird.Import.new(job_args)) do
        {:ok, %Oban.Job{conflict?: true}} -> {:error, :already_running}
        {:ok, _job} -> {:ok, import_log}
      end
    end)
  end

  @doc """
  The user's import runs, newest first.
  """
  def list_import_logs(user) do
    ImportLog.Query.by_user(user)
    |> ImportLog.Query.newest_first()
    |> Repo.all()
  end

  @doc """
  Marks the run as `:running`. A no-op when the log is gone (e.g. the user
  was deleted mid-run).
  """
  def log_started(import_log_id) do
    transition(import_log_id, %{status: :running, started_at: DateTime.utc_now()})
  end

  @doc """
  Marks the run finished with the given `status` (`:completed` or
  `:completed_with_errors`) and its summary counts.
  """
  def log_completed(import_log_id, status, summary) do
    transition(import_log_id, %{
      status: status,
      summary: summary,
      finished_at: DateTime.utc_now()
    })
  end

  @doc """
  Marks the run `:failed` with a human-readable reason.
  """
  def log_failed(import_log_id, error) do
    transition(import_log_id, %{status: :failed, error: error, finished_at: DateTime.utc_now()})
  end

  defp transition(import_log_id, attrs) do
    case Repo.get(ImportLog, import_log_id) do
      nil ->
        :ok

      import_log ->
        {:ok, _} = import_log |> ImportLog.transition_changeset(attrs) |> Repo.update()
        :ok
    end
  end
end
