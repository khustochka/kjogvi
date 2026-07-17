defmodule Kjogvi.Jobs.EbirdPreload do
  @moduledoc """
  Preloads the user's new eBird checklists into the store
  (`Kjogvi.Store.ChecklistPreload`) as an exclusive job: one run per user at
  a time.

  The eBird credentials are resolved here rather than carried in the job
  args — args are persisted as plain JSON (and shown in Oban Web).
  """

  use Kjogvi.Jobs.ExclusiveWorker, unique_keys: [:user_id]

  alias Kjogvi.Accounts
  alias Kjogvi.Ebird
  alias Kjogvi.Store

  @impl Kjogvi.Jobs.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"user_id" => user_id}}), do: {:ebird_preload, user_id}

  @impl Kjogvi.Jobs.ExclusiveWorker
  def start_message(_job), do: "eBird preload in progress..."

  @impl Oban.Worker
  def timeout(_job), do: :timer.minutes(2)

  # The checklists are persisted right here in the job, so they are stored
  # even if every subscribed LiveView is gone before the run finishes. The
  # store is the source of truth for the list; the result only carries the
  # completion message subscribers display. Passing the job itself as the
  # broadcast key makes the progress reports durable on the job row (see
  # `Kjogvi.Jobs.progress/2`).
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}} = job) do
    user = Accounts.get_user!(user_id)

    with {:ok, credentials} <- Ebird.Web.ebird_credentials(user),
         {:ok, checklists} <-
           Ebird.Web.preload_new_checklists_for_user(user, credentials, broadcast_key: job) do
      Store.ChecklistPreload.store_checklists(user, checklists)
      {:ok, %{message: "eBird preload done: #{length(checklists)} new checklists."}}
    end
  end
end
