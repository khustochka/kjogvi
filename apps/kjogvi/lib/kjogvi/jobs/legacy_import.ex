defmodule Kjogvi.Jobs.LegacyImport do
  @moduledoc """
  Runs the legacy import (`Kjogvi.Legacy.Import`) as an exclusive job: one
  run per user at a time.
  """

  use Kjogvi.Jobs.ExclusiveWorker, unique_keys: [:user_id]

  alias Kjogvi.Accounts

  @impl Kjogvi.Jobs.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"user_id" => user_id}}), do: {:legacy_import, user_id}

  @impl Kjogvi.Jobs.ExclusiveWorker
  def start_message(_job), do: "Legacy import in progress..."

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    user = Accounts.get_user!(user_id)

    Kjogvi.Legacy.Import.run(user, broadcast_key: pubsub_key(job))
  end
end
