defmodule Kjogvi.JobsTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Jobs
  alias Kjogvi.TestJobs.SingletonWorker
  alias Kjogvi.TestJobs.SlotWorker
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  # Insert and read back, so the job has the JSON string-keyed args it always
  # has in the real flow (inside perform/1 or the telemetry bridge).
  defp insert_job!(changeset) do
    job = Oban.insert!(changeset)
    Kjogvi.Repo.get!(Oban.Job, job.id, prefix: Oban.config().prefix)
  end

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

    test "loading reports the job's recorded progress over the start message" do
      job = insert_job!(SlotWorker.new(%{user_id: 508}))

      Jobs.progress(job, %{message: "Importing checklists... 42"})

      assert %AsyncResult{loading: %{message: "Importing checklists... 42"}} =
               Jobs.status(SlotWorker, %{user_id: 508})
    end

    test "a finished run reports its outcome, not stale progress" do
      job = insert_job!(SlotWorker.new(%{user_id: 509}))
      Jobs.progress(job, %{message: "Importing checklists... 42"})
      Oban.drain_queue(queue: :imports)

      assert %AsyncResult{ok?: true, loading: nil} = Jobs.status(SlotWorker, %{user_id: 509})
    end
  end

  describe "progress/2" do
    test "for a job, records the progress on the job row and broadcasts it" do
      job = insert_job!(SlotWorker.new(%{user_id: 601}))
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:test_slot, 601}))

      Jobs.progress(job, %{message: "Halfway there..."})

      assert_receive {:progress, {:test_slot, 601}, %{message: "Halfway there..."}}

      assert %Oban.Job{meta: %{"progress" => %{"message" => "Halfway there..."}}} =
               Kjogvi.Repo.get(Oban.Job, job.id, prefix: Oban.config().prefix)
    end

    test "a later report replaces the previous one" do
      job = insert_job!(SlotWorker.new(%{user_id: 602}))

      Jobs.progress(job, %{message: "Importing checklists... 42"})
      Jobs.progress(job, %{message: "Importing observations... 7"})

      assert %AsyncResult{loading: %{message: "Importing observations... 7"}} =
               Jobs.status(SlotWorker, %{user_id: 602})
    end

    test "for a bare task key, only broadcasts" do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:test_slot, 603}))

      Jobs.progress({:test_slot, 603}, %{message: "Working..."})

      assert_receive {:progress, {:test_slot, 603}, %{message: "Working..."}}
    end
  end
end
