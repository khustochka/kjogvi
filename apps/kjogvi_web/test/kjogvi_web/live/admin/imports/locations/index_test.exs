defmodule KjogviWeb.Live.Admin.Imports.Locations.IndexTest do
  # Not async: the tests swap the global Kjogvi.Datasets storage config, and
  # the LiveView process needs the shared (non-async) sandbox connection.
  use KjogviWeb.ConnCase, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo
  alias Kjogvi.Util.PubSubTopic

  defmodule ErroringAdapter do
    @behaviour Kjogvi.Datasets.Adapter

    def configured?(_config), do: true
    def write(_config, _key, _content), do: {:error, :unavailable}
    def read(_config, _key), do: {:error, :unavailable}
    def last_modified(_config, _key), do: {:error, :unavailable}
  end

  defmodule RaisingAdapter do
    @behaviour Kjogvi.Datasets.Adapter

    def configured?(_config), do: true
    def write(_config, _key, _content), do: raise("storage down")
    def read(_config, _key), do: raise("storage down")
    def last_modified(_config, _key), do: raise("storage down")
  end

  # Points the dataset storage at a scratch directory so tests never touch the
  # shared configured path.
  setup %{conn: conn} do
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

    %{conn: login_user(conn, admin_fixture()), dir: dir}
  end

  # The bridge broadcasts lifecycle events on the key's topic; subscribing
  # verifies them end-to-end alongside what the page renders.
  defp subscribe(key) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
  end

  # Oban runs in manual testing mode: submitting a form only enqueues the job,
  # and draining executes it (and fires the lifecycle broadcasts) right here
  # in the test process.
  defp drain_geo_queue do
    Oban.drain_queue(queue: :geo)
  end

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/imports/locations")

    assert response(conn, 404)
  end

  describe "page rendering" do
    test "shows the restore, dump, and ISO import cards", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "h1", "Location Imports")
      assert has_element?(lv, "#restore-common-locations h2", "Restore Common Locations")
      assert has_element?(lv, "#dump-common-locations h2", "Dump Common Locations")
      assert has_element?(lv, "#restore-ebird-locations h2", "Restore eBird Locations")
      assert has_element?(lv, "#dump-ebird-locations h2", "Dump eBird Locations")
      assert has_element?(lv, "h2#initial-imports", "Initial Imports")
      assert has_element?(lv, "#iso-import h2", "ISO 3166 Import")
      assert has_element?(lv, "#ebird-import h2", "eBird Regions Import")
    end

    test "shows common location counts by type", %{conn: conn} do
      country = insert(:country)
      insert(:subdivision1, country_id: country.id)
      # User-owned locations are not part of the dataset.
      insert(:location, user: user_fixture(), country: country)

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-common-locations li", "Country: 1")
      assert has_element?(lv, "#restore-common-locations li", "Subdivision1: 1")
      refute has_element?(lv, "#restore-common-locations li", "Site")
    end

    test "without a snapshot, restore is unavailable and dump reports none yet", %{conn: conn} do
      insert(:country)

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-common-locations-no-snapshot")
      refute has_element?(lv, "#restore-common-locations-form")
      assert has_element?(lv, "#dump-common-locations", "No snapshot yet.")
      assert has_element?(lv, "#dump-common-locations-form button", "Dump")
    end

    test "with no common locations, dump is unavailable", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#dump-common-locations-empty")
      refute has_element?(lv, "#dump-common-locations-form")
    end

    test "shows eBird counts with matched totals", %{conn: conn} do
      location = insert(:country)
      insert(:ebird_location, code: "AD", country_code: "AD", location_id: location.id)
      insert(:ebird_location, code: "UA", country_code: "UA")

      insert(:ebird_location,
        code: "AD-02",
        location_type: :subdivision1,
        country_code: "AD",
        subnational1_code: "AD-02"
      )

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-ebird-locations li", "Country: 2 (1 matched)")
      assert has_element?(lv, "#restore-ebird-locations li", "Subdivision1: 1 (0 matched)")
      assert has_element?(lv, "#restore-ebird-locations li", "Matched: 1 of 3")
    end

    test "with no eBird locations, dump is unavailable", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-ebird-locations li", "No eBird locations yet.")
      assert has_element?(lv, "#dump-ebird-locations-empty")
      refute has_element?(lv, "#dump-ebird-locations-form")
    end
  end

  describe "storage problems" do
    test "with unconfigured storage, shows notices instead of the forms", %{conn: conn} do
      insert(:country)
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: Kjogvi.Datasets.S3Adapter)

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-common-locations-storage-not-configured")
      assert has_element?(lv, "#dump-common-locations-storage-not-configured")
      assert has_element?(lv, "#restore-ebird-locations-storage-not-configured")
      assert has_element?(lv, "#dump-ebird-locations-storage-not-configured")
      assert has_element?(lv, "#locations-import-storage-not-configured")
      assert has_element?(lv, "#ebird-import-storage-not-configured")
      refute has_element?(lv, "#restore-common-locations-form")
      refute has_element?(lv, "#dump-common-locations-form")
      refute has_element?(lv, "#locations-import-form")
      refute has_element?(lv, "#ebird-import-form")
    end

    test "a failed storage check shows a notice and keeps dump available", %{conn: conn} do
      insert(:country)
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: ErroringAdapter)

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-common-locations-snapshot-check-failed")
      refute has_element?(lv, "#restore-common-locations-form")
      assert has_element?(lv, "#locations-import-source-check-failed")

      assert has_element?(
               lv,
               "#dump-common-locations",
               "Checking for an existing snapshot failed."
             )

      assert has_element?(lv, "#dump-common-locations-form button", "Dump")
    end

    test "a raising storage check does not crash the page", %{conn: conn} do
      Application.put_env(:kjogvi, Kjogvi.Datasets, adapter: RaisingAdapter)

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#restore-common-locations-snapshot-check-failed")
      assert has_element?(lv, "#locations-import-source-check-failed")
    end
  end

  describe "dumping" do
    test "writes the snapshot and reports the row count", %{conn: conn, dir: dir} do
      insert(:country, iso_code: "UA")
      subscribe({:geo_dump, :common})

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      lv
      |> element("#dump-common-locations-form")
      |> render_submit()

      assert has_element?(lv, "#dump-common-locations-form button[disabled]", "Dumping…")

      drain_geo_queue()

      assert_receive {:lifecycle, :ok, {:geo_dump, :common}, _async_result}

      assert render(lv) =~ "Dump finished: 1 rows."
      assert File.exists?(Path.join(dir, "geo/common_locations.csv"))
      # The fresh snapshot's timestamp now shows and restore becomes available.
      assert has_element?(lv, "#dump-common-locations", "Current snapshot from")
      assert has_element?(lv, "#restore-common-locations-form button", "Restore")
    end

    test "a second start while a run is pending does not enqueue another job", %{conn: conn} do
      insert(:country, iso_code: "UA")

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      lv |> element("#dump-common-locations-form") |> render_submit()
      # The button is disabled once a run is pending; fire the event directly
      # to simulate a second session racing it.
      render_submit(lv, "start_dump", %{"dataset" => "common_locations"})

      assert %{success: 1} = drain_geo_queue()
    end

    test "a pending run is visible to a freshly mounted page", %{conn: conn} do
      insert(:country, iso_code: "UA")

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")
      lv |> element("#dump-common-locations-form") |> render_submit()

      {:ok, lv2, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv2, "#dump-common-locations-form button[disabled]", "Dumping…")
      assert has_element?(lv2, "#dump-common-locations-status", "Dumping common locations...")
    end
  end

  describe "restoring" do
    test "loads the snapshot and refreshes the counts", %{conn: conn} do
      country = insert(:country, iso_code: "UA")
      insert(:subdivision1, iso_code: "UA-30", country_id: country.id)
      assert {:ok, 2} = Dump.run(:common_locations)
      Location |> Query.only_common() |> Repo.delete_all()

      subscribe({:geo_restore, :common})

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      lv
      |> element("#restore-common-locations-form")
      |> render_submit()

      drain_geo_queue()

      assert_receive {:lifecycle, :ok, {:geo_restore, :common}, _async_result}

      assert render(lv) =~ "Restore finished: 2 rows."
      assert has_element?(lv, "#restore-common-locations li", "Country: 1")
      assert Location |> Query.only_common() |> Repo.aggregate(:count) == 2
    end

    test "a failed restore surfaces the reason", %{conn: conn, dir: dir} do
      # A snapshot exists (so the form renders) but is unreadable content-wise:
      # write it, then break the storage by removing the file after mount.
      insert(:country, iso_code: "UA")
      assert {:ok, 1} = Dump.run(:common_locations)

      subscribe({:geo_restore, :common})

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      File.rm_rf!(dir)

      lv
      |> element("#restore-common-locations-form")
      |> render_submit()

      drain_geo_queue()

      assert_receive {:lifecycle, :error, {:geo_restore, :common}, _async_result}

      assert render(lv) =~ "Restore failed: no snapshot found."
    end
  end

  describe "eBird dataset cards" do
    test "dumping writes the eBird snapshot and reports the row count", %{conn: conn, dir: dir} do
      insert(:ebird_location, code: "AD", country_code: "AD")
      subscribe({:geo_dump, :ebird})

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      lv
      |> element("#dump-ebird-locations-form")
      |> render_submit()

      drain_geo_queue()

      assert_receive {:lifecycle, :ok, {:geo_dump, :ebird}, _async_result}

      assert has_element?(lv, "#dump-ebird-locations-status", "Dump finished: 1 rows.")
      assert File.exists?(Path.join(dir, "geo/ebird_locations.csv"))
      assert has_element?(lv, "#restore-ebird-locations-form button", "Restore")
    end

    test "restoring loads the eBird snapshot and refreshes the counts", %{conn: conn} do
      location = insert(:country)
      insert(:ebird_location, code: "AD", country_code: "AD", location_id: location.id)
      assert {:ok, 1} = Dump.run(:ebird_locations)
      Repo.delete_all(EbirdLocation)

      subscribe({:geo_restore, :ebird})

      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      lv
      |> element("#restore-ebird-locations-form")
      |> render_submit()

      drain_geo_queue()

      assert_receive {:lifecycle, :ok, {:geo_restore, :ebird}, _async_result}

      assert has_element?(lv, "#restore-ebird-locations-status", "Restore finished: 1 rows.")
      assert has_element?(lv, "#restore-ebird-locations li", "Country: 1 (1 matched)")
      assert Repo.aggregate(EbirdLocation, :count) == 1
    end
  end
end
