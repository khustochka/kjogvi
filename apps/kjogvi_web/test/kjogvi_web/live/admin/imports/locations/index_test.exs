defmodule KjogviWeb.Live.Admin.Imports.Locations.IndexTest do
  # Not async: restore/dump run as ExclusiveTaskProcessor tasks in separate
  # processes, which need the shared (non-async) sandbox connection.
  use KjogviWeb.ConnCase, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo
  alias Kjogvi.Util.PubSubTopic

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

  # The processor broadcasts lifecycle events on the key's topic; subscribing
  # lets the test wait for a task deterministically instead of polling.
  defp subscribe(key) do
    Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))
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
      assert has_element?(lv, "#iso-import h2", "ISO 3166 Import")
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

      assert has_element?(lv, "#restore-no-snapshot")
      refute has_element?(lv, "#restore-common-locations-form")
      assert has_element?(lv, "#dump-common-locations", "No snapshot yet.")
      assert has_element?(lv, "#dump-common-locations-form button", "Dump")
    end

    test "with no common locations, dump is unavailable", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports/locations")

      assert has_element?(lv, "#dump-no-locations")
      refute has_element?(lv, "#dump-common-locations-form")
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

      assert_receive {:lifecycle, :ok, {:geo_dump, :common}, _async_result}, 2_000

      assert render(lv) =~ "Dump finished: 1 rows."
      assert File.exists?(Path.join(dir, "geo/common_locations.csv"))
      # The fresh snapshot's timestamp now shows and restore becomes available.
      assert has_element?(lv, "#dump-common-locations", "Current snapshot from")
      assert has_element?(lv, "#restore-common-locations-form button", "Restore")
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

      assert_receive {:lifecycle, :ok, {:geo_restore, :common}, _async_result}, 2_000

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

      assert_receive {:lifecycle, :error, {:geo_restore, :common}, _async_result}, 2_000

      assert render(lv) =~ "Restore failed: no snapshot found."
    end
  end
end
