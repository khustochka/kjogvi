defmodule Kjogvi.Telemetry.LegacyBroadcastTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Jobs
  alias Kjogvi.TestJobs.SlotWorker
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  # The handler is attached globally by Kjogvi.Telemetry.setup/0 at app start,
  # so emitting the events here exercises the real attachment.

  test "with a job as the broadcast key the progress lands on the job row and the key topic" do
    # Read the job back so it has the JSON string-keyed args of the real flow.
    job = Oban.insert!(SlotWorker.new(%{user_id: 701}))
    job = Kjogvi.Repo.get!(Oban.Job, job.id, prefix: Oban.config().prefix)
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:test_slot, 701}))

    :telemetry.execute(
      [:kjogvi, :legacy, :import, :checklists, :progress],
      %{count: 42},
      %{broadcast_key: job}
    )

    assert_receive {:progress, {:test_slot, 701}, %{message: "Importing checklists... 42"}}

    assert %AsyncResult{loading: %{message: "Importing checklists... 42"}} =
             Jobs.status(SlotWorker, %{user_id: 701})
  end

  test "with a bare task key the progress is only broadcast" do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:legacy_import, 702}))

    :telemetry.execute(
      [:kjogvi, :legacy, :import, :observations, :progress],
      %{count: 7},
      %{broadcast_key: {:legacy_import, 702}}
    )

    assert_receive {:progress, {:legacy_import, 702}, %{message: "Importing observations... 7"}}
  end

  test "with a nil broadcast key nothing is broadcast" do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key({:legacy_import, 703}))

    :telemetry.execute(
      [:kjogvi, :legacy, :import, :prepare, :start],
      %{},
      %{broadcast_key: nil}
    )

    refute_receive {:progress, _key, _data}, 50
  end
end
