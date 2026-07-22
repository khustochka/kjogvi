defmodule Kjogvi.Jobs.Ebird.Import do
  @moduledoc """
  Imports a user's uploaded eBird export as an exclusive job: one run per user
  at a time.

  The upload's storage key (`Kjogvi.Imports.Upload`) is carried in the job
  args. The job fetches the `.zip` to a scratch dir, unpacks it, and hands the
  inner CSV to `Kjogvi.Ebird.Import`. On the way out it deletes both the
  scratch dir and the stored upload — the upload is single-use.

  Enqueue through `Kjogvi.Imports.enqueue_ebird_import/2`, which creates the
  run's `ImportLog` and puts its id in the args for
  `Kjogvi.Imports.LogRecorder`.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, unique_keys: [:user_id]

  alias Kjogvi.Accounts
  alias Kjogvi.Imports.Upload

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"user_id" => user_id}}), do: {:ebird_import, user_id}

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def start_message(_job), do: "eBird import in progress..."

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(10)

  # For Kjogvi.Imports.LogRecorder: a run that finished but left rows
  # unimported logs as :completed_with_errors.
  def completion_status(summary) do
    if Kjogvi.Ebird.Import.errors?(summary), do: :completed_with_errors, else: :completed
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id, "upload_key" => upload_key}} = job) do
    user = Accounts.get_user!(user_id)
    scratch = scratch_dir()

    try do
      with {:ok, csv_path} <- fetch_and_unpack(upload_key, scratch) do
        Kjogvi.Ebird.Import.run(user, csv_path, broadcast_key: job)
      end
    after
      File.rm_rf(scratch)
      Upload.delete(upload_key)
    end
  end

  defp fetch_and_unpack(upload_key, scratch) do
    zip_path = Path.join(scratch, "export.zip")

    with :ok <- Upload.fetch_to(upload_key, zip_path),
         {:ok, entries} <- unzip(zip_path, scratch) do
      find_csv(entries)
    end
  end

  # `:zip.unzip` returns the extracted file paths as charlists.
  defp unzip(zip_path, scratch) do
    case :zip.unzip(String.to_charlist(zip_path), cwd: String.to_charlist(scratch)) do
      {:ok, entries} -> {:ok, Enum.map(entries, &to_string/1)}
      {:error, reason} -> {:error, {:bad_zip, reason}}
    end
  end

  defp find_csv(entries) do
    case Enum.find(entries, &(Path.extname(&1) |> String.downcase() == ".csv")) do
      nil -> {:error, :no_csv_in_zip}
      csv_path -> {:ok, csv_path}
    end
  end

  defp scratch_dir do
    Path.join(System.tmp_dir!(), "ebird_import_#{System.unique_integer([:positive])}")
  end
end
