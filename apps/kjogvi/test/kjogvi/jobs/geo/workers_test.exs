defmodule Kjogvi.Jobs.Geo.WorkersTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Jobs.Geo.Dump
  alias Kjogvi.Jobs.Geo.Restore

  test "pubsub_key/1 maps dataset args to the task keys" do
    assert Restore.pubsub_key(%Oban.Job{args: %{"dataset" => "common_locations"}}) ==
             {:geo_restore, :common}

    assert Restore.pubsub_key(%Oban.Job{args: %{"dataset" => "ebird_locations"}}) ==
             {:geo_restore, :ebird}

    assert Dump.pubsub_key(%Oban.Job{args: %{"dataset" => "common_locations"}}) ==
             {:geo_dump, :common}

    assert Dump.pubsub_key(%Oban.Job{args: %{"dataset" => "ebird_locations"}}) ==
             {:geo_dump, :ebird}
  end

  test "start_message/1 names the dataset" do
    assert Restore.start_message(%Oban.Job{args: %{"dataset" => "common_locations"}}) ==
             "Restoring common locations..."

    assert Dump.start_message(%Oban.Job{args: %{"dataset" => "ebird_locations"}}) ==
             "Dumping eBird locations..."
  end

  test "each dataset holds its own exclusive slot" do
    job1 = Oban.insert!(Restore.new(%{dataset: :common_locations}))
    job2 = Oban.insert!(Restore.new(%{dataset: :common_locations}))
    job3 = Oban.insert!(Restore.new(%{dataset: :ebird_locations}))
    job4 = Oban.insert!(Dump.new(%{dataset: :common_locations}))

    assert job2.conflict?
    assert job2.id == job1.id
    refute job3.conflict?
    refute job4.conflict?
  end
end
