defmodule KjogviWeb.Live.Admin.ImportLogs.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Imports

  test "returns 404 for a non-admin user" do
    {:ok, log} = Imports.enqueue_ebird_import(user_fixture(), "a.zip")

    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/import_logs/#{log}")

    assert response(conn, 404)
  end

  describe "show" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows the run and its failed rows", %{conn: conn} do
      user = user_fixture(nickname: "carol")
      {:ok, log} = Imports.enqueue_ebird_import(user, "a.zip")

      :ok =
        Imports.log_completed(log.id, :completed_with_errors, %{
          "checklists_created" => 1,
          "checklists_unmapped" => 1
        })

      :ok =
        Imports.record_errors(log.id, [
          %{
            category: :unmapped,
            submission_id: "S1",
            rows: [%{"Location ID" => "L1", "Common Name" => "Mallard"}]
          }
        ])

      [error] = Imports.list_import_errors(log.id)

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      assert has_element?(lv, "h1", "Import Log ##{log.id}")
      assert has_element?(lv, "#import-log-facts", "carol")
      assert has_element?(lv, "#import-log-facts", "Completed with issues")
      assert has_element?(lv, "#import-error-#{error.id}", "Location unmapped")
      assert has_element?(lv, "#import-error-#{error.id}", "S1")
      assert has_element?(lv, "#import-error-#{error.id}", "Mallard")
    end

    test "shows a failed run's error and upload download link", %{conn: conn} do
      {:ok, log} = Imports.enqueue_ebird_import(user_fixture(), "a.zip")
      :ok = Imports.log_failed(log.id, "it broke")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      assert has_element?(lv, "#import-log-facts", "it broke")
      assert has_element?(lv, "#import-log-facts a[href='/admin/import_logs/#{log.id}/upload']")
      assert has_element?(lv, "#import-errors", "No failed rows recorded")
    end

    test "offers no download once the upload is consumed", %{conn: conn} do
      {:ok, log} = Imports.enqueue_ebird_import(user_fixture(), "a.zip")
      :ok = Imports.log_completed(log.id, :completed, %{})
      :ok = Imports.clear_upload_key(log.id)

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      refute has_element?(lv, "#import-log-facts a[href='/admin/import_logs/#{log.id}/upload']")
    end

    test "notes truncated error records", %{conn: conn} do
      {:ok, log} = Imports.enqueue_ebird_import(user_fixture(), "a.zip")

      :ok =
        Imports.log_completed(log.id, :completed_with_errors, %{"errors_truncated" => true})

      {:ok, _lv, html} = live(conn, ~p"/admin/import_logs/#{log}")

      assert html =~ "The recorded rows were capped"
    end
  end
end
