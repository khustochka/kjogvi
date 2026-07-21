defmodule Kjogvi.Geo.DumpRestoreTest do
  use Kjogvi.DataCase, async: false

  @moduletag :capture_log

  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Geo.Restore
  alias Kjogvi.Repo

  # A scratch file path for one dump, removed on exit.
  defp tmp_csv do
    path =
      Path.join(
        System.tmp_dir!(),
        "geo_dataset_#{System.unique_integer([:positive])}.csv"
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
    |> Enum.map(&Map.take(&1, Dump.columns(:common_locations)))
    |> Enum.sort_by(& &1.id)
  end

  defp delete_common do
    Location |> Query.only_common() |> Repo.delete_all()
  end

  # The dumped columns of every eBird location, code-ordered, for before/after
  # comparison across a dump/restore round trip.
  defp ebird_snapshot do
    EbirdLocation.Query.order_by_code()
    |> Repo.all()
    |> Enum.map(&Map.take(&1, Dump.columns(:ebird_locations)))
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

    test "casts enum columns via the schema type, not the global atom table" do
      # location_type and import_source are restored by casting the CSV string
      # against the schema field's Ecto.Enum — not String.to_existing_atom, which
      # would need the atom preloaded. A valid value round-trips to its atom.
      insert(:subdivision1,
        iso_code: "UA-30",
        country: insert(:country, iso_code: "UA"),
        import_source: :iso
      )

      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:common_locations, path)
      delete_common()
      assert {:ok, 2} = Restore.from_file(:common_locations, path)

      restored = Location |> Query.only_common() |> Repo.all()
      assert :subdivision1 in Enum.map(restored, & &1.location_type)
      assert :iso in Enum.map(restored, & &1.import_source)
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

  describe "ebird_locations dataset" do
    test "dumps rows ordered by code with the match state" do
      location = insert(:country, iso_code: "AD")

      insert(:ebird_location,
        code: "AD-02",
        location_type: :subdivision1,
        country_code: "AD",
        subnational1_code: "AD-02",
        name: "Canillo"
      )

      insert(:ebird_location, code: "AD", country_code: "AD", location_id: location.id)

      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:ebird_locations, path)

      [country_row, sub1_row] = decode_csv(path)
      assert country_row["code"] == "AD"
      assert country_row["location_type"] == "country"
      assert country_row["location_id"] == to_string(location.id)
      assert sub1_row["code"] == "AD-02"
      assert sub1_row["subnational1_code"] == "AD-02"
      assert sub1_row["location_id"] == ""
    end

    test "round-trips the dataset keyed by code" do
      location = insert(:country, iso_code: "AD")

      insert(:ebird_location,
        code: "AD",
        country_code: "AD",
        location_id: location.id,
        name: "Andorra"
      )

      insert(:ebird_location,
        code: "AD-02",
        location_type: :subdivision1,
        country_code: "AD",
        subnational1_code: "AD-02",
        name: "Canillo"
      )

      before_snapshot = ebird_snapshot()
      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:ebird_locations, path)

      Repo.delete_all(EbirdLocation)
      assert {:ok, 2} = Restore.from_file(:ebird_locations, path)

      assert ebird_snapshot() == before_snapshot
    end

    test "refreshes an existing row in place, replacing its match state" do
      location = insert(:country, iso_code: "AD")
      row = insert(:ebird_location, code: "AD", country_code: "AD", location_id: location.id)

      path = tmp_csv()
      assert {:ok, 1} = Dump.to_file(:ebird_locations, path)

      row |> Ecto.Changeset.change(name: "Renamed locally", location_id: nil) |> Repo.update!()

      assert {:ok, 1} = Restore.from_file(:ebird_locations, path)

      restored = Repo.get_by!(EbirdLocation, code: "AD")
      assert restored.name == row.name
      assert restored.location_id == location.id
      assert Repo.aggregate(EbirdLocation, :count) == 1
    end

    test "restores a link that moved to another row despite the unique index" do
      location = insert(:country, iso_code: "AD")
      first = insert(:ebird_location, code: "AA", location_id: location.id)
      second = insert(:ebird_location, code: "BB")

      path = tmp_csv()
      assert {:ok, 2} = Dump.to_file(:ebird_locations, path)

      # Move the link to the other row, as curation after the dump could have.
      Repo.update!(Ecto.Changeset.change(first, location_id: nil))
      Repo.update!(Ecto.Changeset.change(second, location_id: location.id))

      assert {:ok, 2} = Restore.from_file(:ebird_locations, path)

      assert Repo.get_by!(EbirdLocation, code: "AA").location_id == location.id
      assert Repo.get_by!(EbirdLocation, code: "BB").location_id == nil
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

    test "round-trips the eBird dataset under its own snapshot key", %{dir: dir} do
      insert(:ebird_location, code: "AD", country_code: "AD")
      before_snapshot = ebird_snapshot()

      assert {:ok, 1} = Dump.run(:ebird_locations)
      assert File.exists?(Path.join(dir, "geo/ebird_locations.csv"))

      Repo.delete_all(EbirdLocation)
      assert {:ok, 1} = Restore.run(:ebird_locations)

      assert ebird_snapshot() == before_snapshot
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
