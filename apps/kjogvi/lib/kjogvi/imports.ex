defmodule Kjogvi.Imports do
  @moduledoc """
  User-facing data imports: enqueuing import jobs and recording their runs.

  Each run is tracked as a `Kjogvi.Imports.ImportLog`, created together with
  the Oban job and carried in its args as `import_log_id`;
  `Kjogvi.Imports.LogRecorder` moves it through its lifecycle from the job's
  telemetry events. The uploaded source files themselves are handled by
  `Kjogvi.Imports.Upload`.
  """

  alias Kjogvi.Imports.ImportError
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
        %{source: :ebird, user_id: user.id, upload_key: upload_key}
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
  All users' import runs for the admin view, newest first and paginated, with
  users preloaded. `:issues` narrows to runs that failed or finished with
  unimported rows.
  """
  def list_import_logs_for_admin(filter \\ :all, pagination \\ %{}) do
    ImportLog
    |> admin_filter(filter)
    |> ImportLog.Query.newest_first()
    |> ImportLog.Query.preload_user()
    |> Repo.paginate(pagination)
  end

  defp admin_filter(query, :all), do: query
  defp admin_filter(query, :issues), do: ImportLog.Query.with_issues(query)

  @doc """
  The run with its user preloaded. Raises if it doesn't exist.
  """
  def get_import_log!(id) do
    ImportLog.Query.preload_user()
    |> Repo.get!(id)
  end

  @doc """
  Whether the run can be retried: it must have finished and still hold either
  its source upload or recorded failed rows to replay.
  """
  def retryable?(%ImportLog{} = import_log) do
    ImportLog.finished?(import_log) and
      (not is_nil(import_log.upload_key) or has_import_errors?(import_log.id))
  end

  defp has_import_errors?(import_log_id) do
    ImportError.Query.by_import_log(import_log_id) |> Repo.exists?()
  end

  @doc """
  Re-runs a finished eBird import as a fresh run.

  When the original still has its source upload, that file is re-run in full
  (the upload_key moves to the new run so it stays the ground truth); otherwise
  the rows stored on the original's `ImportError` records are replayed. Either
  way the retry is a new `ImportLog` linked back via `retried_from_id`, moving
  through its own lifecycle and appearing in the user's import history.

  Returns `{:error, :not_retryable}` for a run with nothing to replay, and
  `{:error, :already_running}` (rolling the new run back) when an import for the
  same user is already in flight.
  """
  def retry_import(import_log_id) do
    import_log = Repo.get!(ImportLog, import_log_id)

    if retryable?(import_log) do
      Repo.transact(fn -> do_retry(import_log) end)
    else
      {:error, :not_retryable}
    end
  end

  defp do_retry(%ImportLog{upload_key: upload_key} = original) when not is_nil(upload_key) do
    # The upload is single-use ground truth: hand it to the new run so the old
    # run no longer claims a file the retry may consume.
    {:ok, _} = original |> Ecto.Changeset.change(upload_key: nil) |> Repo.update()

    with {:ok, retry} <- insert_retry_log(original, upload_key) do
      enqueue_retry(retry, %{
        user_id: original.user_id,
        upload_key: upload_key,
        import_log_id: retry.id
      })
    end
  end

  defp do_retry(%ImportLog{} = original) do
    with {:ok, retry} <- insert_retry_log(original, nil) do
      enqueue_retry(retry, %{
        user_id: original.user_id,
        import_log_id: retry.id,
        retry_of: original.id
      })
    end
  end

  defp insert_retry_log(original, upload_key) do
    %{
      source: original.source,
      user_id: original.user_id,
      upload_key: upload_key,
      retried_from_id: original.id
    }
    |> ImportLog.create_changeset()
    |> Repo.insert()
  end

  defp enqueue_retry(retry, job_args) do
    case Oban.insert(Kjogvi.Jobs.Ebird.Import.new(job_args)) do
      {:ok, %Oban.Job{conflict?: true}} -> {:error, :already_running}
      {:ok, _job} -> {:ok, retry}
    end
  end

  @doc """
  The rows stored across a run's `ImportError` records, flattened in order —
  the payload a stored-rows retry replays.
  """
  def stored_import_rows(import_log_id) do
    import_log_id
    |> list_import_errors()
    |> Enum.flat_map(& &1.rows)
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

  @doc """
  Persists a run's failed rows as `ImportError` records, in the order given.

  Entries are maps with `:category` and `:rows`, plus optional
  `:submission_id` and `:error`.
  """
  def record_errors(_import_log_id, []), do: :ok

  def record_errors(import_log_id, entries) do
    now = DateTime.utc_now()

    rows =
      Enum.map(entries, fn entry ->
        %{
          category: Map.fetch!(entry, :category),
          rows: Map.fetch!(entry, :rows),
          submission_id: Map.get(entry, :submission_id),
          error: Map.get(entry, :error),
          import_log_id: import_log_id,
          inserted_at: now,
          updated_at: now
        }
      end)

    {_count, nil} = Repo.insert_all(ImportError, rows)
    :ok
  end

  @doc """
  The failed rows recorded for the run, oldest first.
  """
  def list_import_errors(import_log_id) do
    ImportError.Query.by_import_log(import_log_id)
    |> ImportError.Query.oldest_first()
    |> Repo.all()
  end

  @doc """
  The run's failed rows for the admin view, oldest first and paginated.
  """
  def paginate_import_errors(import_log_id, pagination \\ %{}) do
    ImportError.Query.by_import_log(import_log_id)
    |> ImportError.Query.oldest_first()
    |> Repo.paginate(pagination)
  end

  @doc """
  Unlinks the run's consumed (deleted) upload. `nil` — a job enqueued without
  a log — is a no-op.
  """
  def clear_upload_key(nil), do: :ok

  def clear_upload_key(import_log_id) do
    case Repo.get(ImportLog, import_log_id) do
      nil ->
        :ok

      import_log ->
        {:ok, _} = import_log |> Ecto.Changeset.change(upload_key: nil) |> Repo.update()
        :ok
    end
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
