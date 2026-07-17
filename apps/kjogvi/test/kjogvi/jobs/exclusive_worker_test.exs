defmodule Kjogvi.Jobs.ExclusiveWorkerTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.TestJobs.SingletonWorker
  alias Kjogvi.TestJobs.SlotWorker

  describe "exclusive slot" do
    test "a second insert while a run is in flight returns the existing job" do
      job1 = Oban.insert!(SlotWorker.new(%{user_id: 510}))
      job2 = Oban.insert!(SlotWorker.new(%{user_id: 510}))

      assert job2.conflict?
      assert job2.id == job1.id
    end

    test "uniqueness is keyed on the unique_keys args only" do
      job1 = Oban.insert!(SlotWorker.new(%{user_id: 511}))
      job2 = Oban.insert!(SlotWorker.new(%{user_id: 511, result: "other"}))

      assert job2.conflict?
      assert job2.id == job1.id
    end

    test "different slots run independently" do
      job1 = Oban.insert!(SlotWorker.new(%{user_id: 512}))
      job2 = Oban.insert!(SlotWorker.new(%{user_id: 513}))

      refute job2.conflict?
      refute job2.id == job1.id
    end

    test "a finished run frees the slot" do
      Oban.insert!(SlotWorker.new(%{user_id: 514}))
      Oban.drain_queue(queue: :imports)

      job2 = Oban.insert!(SlotWorker.new(%{user_id: 514}))
      refute job2.conflict?
    end
  end

  describe "defaults" do
    test "enqueues single-shot jobs on the imports queue" do
      job = Oban.insert!(SlotWorker.new(%{user_id: 520}))

      assert job.queue == "imports"
      assert job.max_attempts == 1
    end

    test "a failed job is discarded, not retried" do
      Oban.insert!(SlotWorker.new(%{user_id: 521, error: true}))

      assert %{discard: 1, failure: 0} = Oban.drain_queue(queue: :imports)
    end

    test "queue is overridable" do
      job = Oban.insert!(SingletonWorker.new(%{}))

      assert job.queue == "geo"
    end

    test "timeout defaults to five minutes" do
      assert SlotWorker.timeout(%Oban.Job{}) == :timer.minutes(5)
    end
  end
end
