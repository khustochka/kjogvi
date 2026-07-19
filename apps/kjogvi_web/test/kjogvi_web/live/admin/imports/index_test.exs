defmodule KjogviWeb.Live.Admin.Imports.IndexTest do
  # Not async: the bootstrap tests swap the global Kjogvi.Datasets storage
  # config, and the LiveView process needs the shared (non-async) sandbox
  # connection.
  use KjogviWeb.ConnCase, async: false

  @moduletag :capture_log

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Jobs
  alias Kjogvi.Util.PubSubTopic

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/imports")

    assert response(conn, 404)
  end

  describe "page rendering" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows the heading", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      assert has_element?(lv, "h1", "Imports")
    end

    test "links to the location imports workbench", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      assert has_element?(lv, "a[href='/admin/imports/locations']", "Location Imports")
    end

    test "offers the bootstrap card naming the configured taxonomy", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      assert has_element?(lv, "#bootstrap")
      assert has_element?(lv, "#bootstrap-form button", "Bootstrap")

      assert has_element?(
               lv,
               "#bootstrap li",
               Kjogvi.Settings.default_taxonomy_importer().name()
             )
    end
  end

  describe "bootstrap" do
    # Point dataset storage at an empty scratch dir: the restores then fail with
    # :enoent, which drives the job to a terminal state. The taxonomy step runs
    # first, so it is pointed at the offline demo importer rather than the
    # configured default, which would download a real source file.
    setup %{conn: conn} do
      dir = Path.join(System.tmp_dir!(), "datasets_#{System.unique_integer([:positive])}")
      original_datasets = Application.get_env(:kjogvi, Kjogvi.Datasets)
      original_settings = Application.get_env(:kjogvi, Kjogvi.Settings, [])

      Application.put_env(:kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.LocalAdapter,
        path: dir
      )

      Application.put_env(
        :kjogvi,
        Kjogvi.Settings,
        Keyword.put(original_settings, :default_taxonomy_importer, Ornitho.Importer.Demo.V1)
      )

      on_exit(fn ->
        Application.put_env(:kjogvi, Kjogvi.Datasets, original_datasets)
        Application.put_env(:kjogvi, Kjogvi.Settings, original_settings)
        File.rm_rf(dir)
      end)

      %{conn: login_user(conn, admin_fixture())}
    end

    test "enqueues a single exclusive job and reports it as running", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      lv |> element("#bootstrap-form") |> render_submit()

      assert has_element?(lv, "#bootstrap-form button[disabled]", "Bootstrapping…")
      assert [_job] = all_enqueued(worker: Jobs.Bootstrap)

      # A second submit while in flight must not enqueue a duplicate.
      lv |> element("#bootstrap-form") |> render_submit()
      assert [_job] = all_enqueued(worker: Jobs.Bootstrap)
    end

    test "reports a failed step on the status line", %{conn: conn} do
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(Jobs.Bootstrap.task_key()))

      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      lv |> element("#bootstrap-form") |> render_submit()
      Oban.drain_queue(queue: :imports)

      assert_receive {:lifecycle, _event, _key, _async_result}

      assert lv |> element("#bootstrap-status") |> render() =~ "Bootstrap failed"
    end
  end
end
