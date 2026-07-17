defmodule Kjogvi.JobsTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Jobs
  alias Kjogvi.TestJobs.SingletonWorker
  alias Kjogvi.TestJobs.SlotWorker
  alias Kjogvi.Util.AsyncResult

  describe "status/2" do
    test "blank when the slot has never run" do
      assert Jobs.status(SlotWorker, %{user_id: 501}) == %AsyncResult{}
    end

    test "loading while a job is enqueued" do
      Oban.insert!(SlotWorker.new(%{user_id: 502}))

      assert %AsyncResult{loading: %{message: "In progress..."}} =
               Jobs.status(SlotWorker, %{user_id: 502})
    end

    test "loading message comes from the worker's start_message/1" do
      Oban.insert!(SingletonWorker.new(%{}))

      assert %AsyncResult{loading: %{message: "Testing the singleton..."}} =
               Jobs.status(SingletonWorker)
    end

    test "ok after a successful run" do
      Oban.insert!(SlotWorker.new(%{user_id: 503}))
      Oban.drain_queue(queue: :imports)

      assert %AsyncResult{ok?: true, loading: nil, failed: nil} =
               Jobs.status(SlotWorker, %{user_id: 503})
    end

    test "failed after an errored run" do
      Oban.insert!(SlotWorker.new(%{user_id: 504, error: true}))
      Oban.drain_queue(queue: :imports)

      assert %AsyncResult{failed: failed} = Jobs.status(SlotWorker, %{user_id: 504})
      assert failed =~ ":boom"
    end

    test "statuses are scoped to the args slot" do
      Oban.insert!(SlotWorker.new(%{user_id: 505}))

      assert Jobs.status(SlotWorker, %{user_id: 506}) == %AsyncResult{}
    end

    test "a new run reports loading again after an earlier one finished" do
      Oban.insert!(SlotWorker.new(%{user_id: 507}))
      Oban.drain_queue(queue: :imports)
      Oban.insert!(SlotWorker.new(%{user_id: 507}))

      assert %AsyncResult{loading: %{message: _}} = Jobs.status(SlotWorker, %{user_id: 507})
    end
  end
end
