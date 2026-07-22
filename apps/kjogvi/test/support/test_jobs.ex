defmodule Kjogvi.TestJobs.SlotWorker do
  @moduledoc """
  Exclusive test worker with a per-user slot, steerable through its args.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, unique_keys: [:user_id]

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(%Oban.Job{args: %{"user_id" => user_id}}), do: {:test_slot, user_id}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"error" => true}}), do: {:error, :boom}
  def perform(%Oban.Job{args: %{"raise" => true}}), do: raise("boom")
  def perform(%Oban.Job{args: %{"result" => value}}), do: {:ok, value}
  def perform(_job), do: {:ok, :done}
end

defmodule Kjogvi.TestJobs.SingletonWorker do
  @moduledoc """
  Exclusive test worker with a single argument-free slot and overridden
  queue and start message.
  """

  use Kjogvi.Jobs.Runtime.ExclusiveWorker, queue: :geo

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def pubsub_key(_job), do: {:test_singleton, :common}

  @impl Kjogvi.Jobs.Runtime.ExclusiveWorker
  def start_message(_job), do: "Testing the singleton..."

  @impl Oban.Worker
  def perform(_job), do: {:ok, 7}
end

defmodule Kjogvi.TestJobs.PlainWorker do
  @moduledoc """
  A plain Oban worker (not an ExclusiveWorker) — the bridge must ignore it.
  """

  use Oban.Worker, queue: :imports, max_attempts: 1

  @impl Oban.Worker
  def perform(_job), do: :ok
end

defmodule Kjogvi.TestJobs.LoggedWorker do
  @moduledoc """
  A worker carrying an `import_log_id` for `Kjogvi.Imports.LogRecorder`,
  steerable through its args, with a `completion_status/1` driven by the
  summary it returns.
  """

  use Oban.Worker, queue: :imports, max_attempts: 1

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"error" => reason}}), do: {:error, reason}
  def perform(%Oban.Job{args: %{"raise" => true}}), do: raise("logged boom")
  def perform(%Oban.Job{args: %{"cancel" => reason}}), do: {:cancel, reason}
  def perform(%Oban.Job{args: %{"summary" => summary}}), do: {:ok, summary}
  def perform(_job), do: :ok

  def completion_status(%{"errors" => true}), do: :completed_with_errors
  def completion_status(_summary), do: :completed
end
