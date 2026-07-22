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

    test "offers a retry for a finished run holding its upload", %{conn: conn} do
      log = finished_run(user_fixture(), upload_key: "a.zip")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      assert has_element?(lv, "#retry-import")
    end

    test "offers no retry for a run with nothing to replay", %{conn: conn} do
      log = finished_run(user_fixture(), upload_key: nil)

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      refute has_element?(lv, "#retry-import")
    end

    test "retrying navigates to the new run", %{conn: conn} do
      log = finished_run(user_fixture(), upload_key: "a.zip")

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{log}")

      {:error, {:live_redirect, %{to: to}}} =
        lv |> element("#retry-import") |> render_click()

      assert to =~ ~r"^/admin/import_logs/\d+$"
      refute to == "/admin/import_logs/#{log.id}"
    end

    test "links a retry back to the run it re-ran", %{conn: conn} do
      original = finished_run(user_fixture(), upload_key: "a.zip")
      {:ok, retry} = Imports.retry_import(original.id)

      {:ok, lv, _html} = live(conn, ~p"/admin/import_logs/#{retry}")

      assert has_element?(
               lv,
               "#import-log-facts a[href='/admin/import_logs/#{original.id}']"
             )
    end
  end

  # A finished run inserted directly (no Oban job), leaving the user's exclusive
  # import slot free for a retry.
  defp finished_run(user, opts) do
    {:ok, log} =
      %{source: :ebird, user_id: user.id, upload_key: opts[:upload_key]}
      |> Kjogvi.Imports.ImportLog.create_changeset()
      |> Kjogvi.Repo.insert()

    :ok = Imports.log_completed(log.id, :completed, %{})
    Kjogvi.Repo.get!(Kjogvi.Imports.ImportLog, log.id)
  end
end
