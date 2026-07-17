defmodule Kjogvi.TestJobs.SlotWorker do
  @moduledoc """
  Exclusive test worker with a per-user slot, steerable through its args.
  """

  use Kjogvi.Jobs.ExclusiveWorker, unique_keys: [:user_id]

  @impl Kjogvi.Jobs.ExclusiveWorker
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

  use Kjogvi.Jobs.ExclusiveWorker, queue: :geo

  @impl Kjogvi.Jobs.ExclusiveWorker
  def pubsub_key(_job), do: {:test_singleton, :common}

  @impl Kjogvi.Jobs.ExclusiveWorker
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
