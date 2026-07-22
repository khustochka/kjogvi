defmodule Kjogvi.Imports.ImportLog do
  @moduledoc """
  A record of one import run, from enqueue to outcome.

  Created when the import job is enqueued and kept current by
  `Kjogvi.Imports.LogRecorder` as the job moves through its lifecycle:

      :queued -> :running -> :completed | :completed_with_errors | :failed

  `summary` holds the run's counts as returned by the import (string-keyed
  once read back). `:completed_with_errors` means the run finished but some
  rows were not imported; those rows are kept as `Kjogvi.Imports.ImportError`
  records. `error` carries the failure reason of a `:failed` run. A row stuck
  in `:running` past the job timeout means the run died without reporting
  (e.g. a VM crash).

  `upload_key` points at the run's source file (`Kjogvi.Imports.Upload`),
  recorded at enqueue. A cleanly consumed upload is deleted and the key
  cleared; a key still present means the file was retained — the run failed
  outright, died, or overflowed the per-run `ImportError` cap.

  `retried_from` points at the run this one re-ran (a retry is always a fresh
  run with its own lifecycle and history entry), for the admin audit trail.
  """

  use Kjogvi.Schema

  import Ecto.Changeset

  alias Kjogvi.Accounts.User

  @statuses [:queued, :running, :completed, :completed_with_errors, :failed]

  schema "import_logs" do
    field :source, Ecto.Enum, values: Kjogvi.Types.ImportSource.values()
    field :status, Ecto.Enum, values: @statuses, default: :queued
    field :summary, :map, default: %{}
    field :error, :string
    field :upload_key, :string
    field :started_at, :utc_datetime_usec
    field :finished_at, :utc_datetime_usec

    belongs_to(:user, User)
    belongs_to(:retried_from, __MODULE__)

    timestamps()
  end

  @doc false
  def create_changeset(attrs) do
    %__MODULE__{}
    |> cast(attrs, [:source, :user_id, :upload_key, :retried_from_id])
    |> validate_required([:source, :user_id])
    |> assoc_constraint(:user)
  end

  @doc false
  def transition_changeset(import_log, attrs) do
    import_log
    |> cast(attrs, [:status, :summary, :error, :started_at, :finished_at])
    |> validate_required([:status])
  end

  def finished?(%__MODULE__{status: status}) do
    status in [:completed, :completed_with_errors, :failed]
  end
end
