defmodule Kjogvi.Geo.DumpRestoreTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Geo.Restore
  alias Kjogvi.Repo

  # A scratch file path for one dump, removed on exit.
  defp tmp_csv do
    path =
      Path.join(
        System.tmp_dir!(),
        "common_locations_#{System.unique_integer([:positive])}.csv"
      )

    on_exit(fn -> File.rm(path) end)
    path
  end

  defp decode_csv(path) do
    path
    |> File.stream!()
    |> CSV.decode!(headers: true)
    |> Enum.to_list()
  end

  # The dumped columns of every common location, id-ordered, for before/after
  # comparison across a dump/restore round trip.
  defp common_snapshot do
    Location
    |> Query.only_common()
    |> Repo.all()
    |> Enum.map(&Map.take(&1, Dump.columns()))
    |> Enum.sort_by(& &1.id)
  end

  defp delete_common do
    Location |> Query.only_common() |> Repo.delete_all()
  end

  describe "Dump.to_file/2" do
    test "writes all common locations, parents before children" do
      country = insert(:country, iso_code: "UA")
      subdivision = insert(:subdivision1, iso_code: "UA-30", country_id: country.id)
      # Inserted after the subdivision, so id order alone would misplace it.
      other_country = insert(:country, iso_code: "US")

      path = tmp_csv()
      assert {:ok, 3} = Dump.to_file(:common_locations, path)

      slugs = path |> decode_csv() |> Enum.map(& &1["slug"])
      assert slugs == [country.slug, other_country.slug, subdivision.slug]
    end

    test "excludes user-owned locations" do
      insert(:country, iso_code: "UA")
      user = Kjogvi.AccountsFixtures.user_fixture()
      insert(:location, user: user, slug: "my_place")

      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:common_locations, path)

      refute "my_place" in (path |> decode_csv() |> Enum.map(& &1["slug"]))
    end

    test "encodes every dumped column" do
      country =
        insert(:country,
          iso_code: "UA",
          lat: Decimal.new("49.53"),
          lon: Decimal.new("31.28"),
          public_index: 7,
          import_source: :iso,
          extras: %{"numeric" => "804"}
        )

      path = tmp_csv()
      assert {:ok, 1} = Dump.to_file(:common_locations, path)

      [row] = decode_csv(path)
      assert row["id"] == to_string(country.id)
      assert row["slug"] == country.slug
      assert row["name_en"] == country.name_en
      assert row["location_type"] == "country"
      assert row["iso_code"] == "UA"
      # The lat/lon columns carry a fixed scale, so compare numerically.
      assert Decimal.equal?(Decimal.new(row["lat"]), Decimal.new("49.53"))
      assert Decimal.equal?(Decimal.new(row["lon"]), Decimal.new("31.28"))
      assert row["is_private"] == "false"
      assert row["public_index"] == "7"
      assert row["import_source"] == "iso"
      assert row["extras"] == ~s({"numeric":"804"})
      assert row["country_id"] == ""
    end
  end

  describe "Restore.from_file/2" do
    test "round-trips the dataset with ids and level FKs preserved" do
      country =
        insert(:country,
          iso_code: "UA",
          lat: Decimal.new("49.53"),
          extras: %{"numeric" => "804"},
          import_source: :iso
        )

      insert(:subdivision1, iso_code: "UA-30", country_id: country.id, is_private: true)

      before_snapshot = common_snapshot()
      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:common_locations, path)

      delete_common()
      assert {:ok, 2} = Restore.from_file(:common_locations, path)

      assert common_snapshot() == before_snapshot
    end

    test "refreshes an existing common row in place instead of duplicating it" do
      country = insert(:country, iso_code: "UA", name_en: "Ukraine")

      path = tmp_csv()
      assert {:ok, 1} = Dump.to_file(:common_locations, path)

      country |> Ecto.Changeset.change(name_en: "Renamed locally") |> Repo.update!()

      assert {:ok, 1} = Restore.from_file(:common_locations, path)

      restored = Repo.get!(Location, country.id)
      assert restored.name_en == "Ukraine"
      assert Repo.aggregate(Location, :count) == 1
    end

    test "leaves user-owned locations untouched" do
      insert(:country, iso_code: "UA")
      user = Kjogvi.AccountsFixtures.user_fixture()
      # No country, so wiping the common rows below doesn't trip its FK.
      mine = insert(:location, user: user, country: nil)

      path = tmp_csv()
      assert {:ok, _} = Dump.to_file(:common_locations, path)
      delete_common()

      assert {:ok, _} = Restore.from_file(:common_locations, path)

      after_restore = Repo.get!(Location, mine.id)
      assert after_restore.user_id == user.id
      assert after_restore.name_en == mine.name_en
    end

    test "aborts when a snapshot id collides with a user-owned location" do
      country = insert(:country, iso_code: "UA")

      path = tmp_csv()
      assert {:ok, 1} = Dump.to_file(:common_locations, path)

      # Re-create the dumped id as a user-owned row, as another environment
      # whose users raced the sequence could have.
      delete_common()
      user = Kjogvi.AccountsFixtures.user_fixture()
      mine = insert(:location, user: user, id: country.id, country: nil)

      assert {:error, {:user_owned_id_collision, [collision_id]}} =
               Restore.from_file(:common_locations, path)

      assert collision_id == country.id
      # Nothing was committed: the user row is intact and no common row landed.
      assert Repo.get!(Location, mine.id).user_id == user.id
      assert Location |> Query.only_common() |> Repo.aggregate(:count) == 0
    end

    test "bumps the id sequence past the restored ids and the reserved floor" do
      insert(:country, iso_code: "UA")

      path = tmp_csv()
      assert {:ok, _} = Dump.to_file(:common_locations, path)
      delete_common()
      assert {:ok, _} = Restore.from_file(:common_locations, path)

      restored_max = Repo.aggregate(Location, :max, :id)
      next = insert(:country)
      assert next.id > restored_max
      assert next.id >= 10_000
    end
  end

  describe "run/1 through the configured storage" do
    setup do
      dir = Path.join(System.tmp_dir!(), "datasets_#{System.unique_integer([:positive])}")
      original = Application.get_env(:kjogvi, Kjogvi.Datasets)

      Application.put_env(:kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.LocalAdapter,
        path: dir
      )

      on_exit(fn ->
        Application.put_env(:kjogvi, Kjogvi.Datasets, original)
        File.rm_rf(dir)
      end)

      %{dir: dir}
    end

    test "round-trips via the local adapter under the fixed snapshot key", %{dir: dir} do
      country = insert(:country, iso_code: "UA")
      before_snapshot = common_snapshot()

      assert {:ok, 1} = Dump.run(:common_locations)
      assert File.exists?(Path.join(dir, "geo/common_locations.csv"))

      delete_common()
      assert {:ok, 1} = Restore.run(:common_locations)

      assert common_snapshot() == before_snapshot
      assert Repo.get!(Location, country.id).slug == country.slug
    end

    test "restore errors when no snapshot exists" do
      assert {:error, :enoent} = Restore.run(:common_locations)
    end
  end

  describe "telemetry" do
    # Forwards the dump/restore stop events to the test process.
    defp attach_handlers(events) do
      ref = make_ref()
      test_pid = self()

      :telemetry.attach_many(
        {__MODULE__, ref},
        events,
        fn event, measurements, metadata, _ ->
          send(test_pid, {:telemetry, event, measurements, metadata})
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach({__MODULE__, ref}) end)
    end

    test "dump and restore emit stop events with the dataset and row count" do
      attach_handlers([[:kjogvi, :geo, :dump, :stop], [:kjogvi, :geo, :restore, :stop]])

      insert(:country, iso_code: "UA")
      path = tmp_csv()

      assert {:ok, 1} = Dump.to_file(:common_locations, path)

      assert_received {:telemetry, [:kjogvi, :geo, :dump, :stop], %{duration: _},
                       %{dataset: :common_locations, result: :ok, count: 1}}

      assert {:ok, 1} = Restore.from_file(:common_locations, path)

      assert_received {:telemetry, [:kjogvi, :geo, :restore, :stop], %{duration: _},
                       %{dataset: :common_locations, result: :ok, count: 1}}
    end

    test "a failed restore emits a stop event carrying the reason" do
      attach_handlers([[:kjogvi, :geo, :restore, :stop]])

      country = insert(:country, iso_code: "UA")
      path = tmp_csv()
      assert {:ok, 1} = Dump.to_file(:common_locations, path)

      delete_common()
      user = Kjogvi.AccountsFixtures.user_fixture()
      insert(:location, user: user, id: country.id)

      assert {:error, reason} = Restore.from_file(:common_locations, path)

      assert_received {:telemetry, [:kjogvi, :geo, :restore, :stop], %{duration: _},
                       %{result: :error, reason: ^reason}}
    end
  end
end
