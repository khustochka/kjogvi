# Not async: the assertions on the shared global lifecycle topic (and the
# refute_receive) would race with job drains from concurrently running tests.
defmodule Kjogvi.Jobs.BridgeTest do
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Jobs.Bridge
  alias Kjogvi.TestJobs.PlainWorker
  alias Kjogvi.TestJobs.SingletonWorker
  alias Kjogvi.TestJobs.SlotWorker
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  test "broadcasts start and ok on the key topic for a successful job" do
    key = {:test_slot, 601}
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

    Oban.insert!(SlotWorker.new(%{user_id: 601, result: "imported"}))
    Oban.drain_queue(queue: :imports)

    assert_receive {:lifecycle, :start, ^key, %AsyncResult{loading: %{message: "In progress..."}}}

    assert_receive {:lifecycle, :ok, ^key, %AsyncResult{ok?: true, result: "imported"}}
  end

  test "broadcasts error with the unwrapped reason when the job returns an error" do
    key = {:test_slot, 602}
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

    Oban.insert!(SlotWorker.new(%{user_id: 602, error: true}))
    Oban.drain_queue(queue: :imports)

    assert_receive {:lifecycle, :start, ^key, %AsyncResult{loading: %{}}}
    assert_receive {:lifecycle, :error, ^key, %AsyncResult{failed: :boom}}
  end

  test "broadcasts error with the exception when the job raises" do
    key = {:test_slot, 603}
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

    Oban.insert!(SlotWorker.new(%{user_id: 603, raise: true}))
    Oban.drain_queue(queue: :imports)

    assert_receive {:lifecycle, :error, ^key,
                    %AsyncResult{failed: %RuntimeError{message: "boom"}}}
  end

  test "mirrors every event on the global lifecycle topic" do
    key = {:test_singleton, :common}
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, Bridge.lifecycle_topic())

    Oban.insert!(SingletonWorker.new(%{}))
    Oban.drain_queue(queue: :geo)

    assert_receive {:lifecycle, :start, ^key,
                    %AsyncResult{loading: %{message: "Testing the singleton..."}}}

    assert_receive {:lifecycle, :ok, ^key, %AsyncResult{ok?: true, result: 7}}
  end

  test "ignores jobs of plain Oban workers" do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, Bridge.lifecycle_topic())

    Oban.insert!(PlainWorker.new(%{}))
    Oban.drain_queue(queue: :imports)

    refute_receive {:lifecycle, _, _, _}
  end
end
