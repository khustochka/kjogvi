defmodule KjogviWeb.Live.Admin.ImportLogs.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Imports

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/import_logs")

    assert response(conn, 404)
  end

  describe "index" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "lists runs across users with owner and status", %{conn: conn} do
      alice = user_fixture(nickname: "alice")
      bob = user_fixture(nickname: "bob")

      {:ok, queued} = Imports.enqueue_ebird_import(alice, "a.zip")
      {:ok, failed} = Imports.enqueue_ebird_import(bob, "b.zip")
      :ok = Imports.log_failed(failed.id, "boom")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs")

      assert has_element?(lv, "h1", "Import Logs")
      assert has_element?(lv, "#import-log-#{queued.id}", "alice")
      assert has_element?(lv, "#import-log-#{queued.id}", "Queued")
      assert has_element?(lv, "#import-log-#{failed.id}", "bob")
      assert has_element?(lv, "#import-log-#{failed.id}", "Failed")
      assert has_element?(lv, "#import-log-#{failed.id}", "boom")
    end

    test "the issues filter hides clean runs", %{conn: conn} do
      alice = user_fixture()
      bob = user_fixture()

      {:ok, completed} = Imports.enqueue_ebird_import(alice, "a.zip")
      :ok = Imports.log_completed(completed.id, :completed, %{})
      {:ok, failed} = Imports.enqueue_ebird_import(bob, "b.zip")
      :ok = Imports.log_failed(failed.id, "boom")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs?status=issues")

      assert has_element?(lv, "#import-log-#{failed.id}")
      refute has_element?(lv, "#import-log-#{completed.id}")
    end

    test "marks finished runs with a retained upload", %{conn: conn} do
      alice = user_fixture()
      bob = user_fixture()

      {:ok, queued} = Imports.enqueue_ebird_import(alice, "a.zip")
      {:ok, failed} = Imports.enqueue_ebird_import(bob, "b.zip")
      :ok = Imports.log_failed(failed.id, "boom")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs")

      assert has_element?(lv, "#import-log-#{failed.id}", "Upload retained")
      # A queued run's pending upload isn't "retained".
      refute has_element?(lv, "#import-log-#{queued.id}", "Upload retained")
    end

    test "rows link to the run's detail page", %{conn: conn} do
      {:ok, log} = Imports.enqueue_ebird_import(user_fixture(), "a.zip")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs")

      assert has_element?(lv, "#import-log-#{log.id} a[href='/admin/import_logs/#{log.id}']")
    end
  end
end
