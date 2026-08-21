defmodule KjogviWeb.Live.My.Ebird.IndexTest do
  use KjogviWeb.ConnCase, async: true

  @moduletag :capture_log

  import Phoenix.LiveViewTest

  alias Kjogvi.Imports
  alias Kjogvi.Jobs
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  defp flush_render(lv) do
    _ = render(lv)
    render(lv)
  end

  defp broadcast_progress(key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:progress, key, data}
    )
  end

  defp broadcast_lifecycle(key, event, async_result) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:lifecycle, event, key, async_result}
    )
  end

  defp csv_zip do
    {:ok, {_name, bin}} =
      :zip.create(~c"export.zip", [{~c"MyEBirdData.csv", "Row ID,Common Name\n1,Mallard\n"}], [
        :memory
      ])

    bin
  end

  describe "page rendering" do
    test "shows the eBird CSV import task", %{conn: conn} do
      {:ok, lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.user_fixture())
        |> live(~p"/my/ebird")

      assert html =~ "eBird Import"
      assert has_element?(lv, "#ebird-csv-import-form")
      # The other import tasks stay on /my/imports.
      refute has_element?(lv, "#legacy-import-form")
      refute has_element?(lv, "#ebird-preload-form")
    end

    test "redirects when not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/ebird")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/account/login"
    end
  end

  describe "eBird CSV import" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      %{lv: lv, user: user}
    end

    # The run itself is exercised in Kjogvi.Jobs.Ebird.ImportTest; here it is
    # never drained, so these tests stop at the enqueued job.
    test "uploading a zip stashes it and enqueues the import job", %{lv: lv, user: user} do
      # `:zip.create` bakes the current time into each entry's header, so reuse
      # one zip for both the upload and the round-trip assertion — generating it
      # twice can straddle a second boundary and differ by a timestamp byte.
      zip = csv_zip()

      file =
        file_input(lv, "#ebird-csv-import-form", :ebird_zip, [
          %{name: "MyEBirdData.zip", content: zip, type: "application/zip"}
        ])

      assert render_upload(file, "MyEBirdData.zip") =~ "MyEBirdData.zip"

      lv |> element("#ebird-csv-import-form") |> render_submit()

      assert has_element?(lv, "#ebird-csv-import-form button[disabled]")
      assert render(lv) =~ "eBird import in progress..."

      assert %AsyncResult{loading: %{message: _}} =
               Jobs.status(Jobs.Ebird.Import, %{user_id: user.id})

      # The job carries the stored upload key, and the file is on disk for it.
      [%Oban.Job{args: %{"upload_key" => key}}] =
        Oban.Job |> Kjogvi.Repo.all(prefix: Oban.config().prefix)

      dest =
        Path.join(System.tmp_dir!(), "kjogvi_csv_fetch_#{System.unique_integer([:positive])}")

      on_exit(fn -> File.rm(dest) end)
      assert :ok = Kjogvi.Imports.Upload.fetch_to(key, dest)
      assert File.read!(dest) == zip
    end

    test "submitting with no file selected shows an error and enqueues nothing",
         %{lv: lv, user: user} do
      html = lv |> element("#ebird-csv-import-form") |> render_submit()

      assert html =~ "Choose an eBird export (.zip) to import."
      assert Jobs.status(Jobs.Ebird.Import, %{user_id: user.id}) == %AsyncResult{}
    end

    test "a second upload while an import runs is rejected and not orphaned",
         %{lv: lv, user: user} do
      # An import is already in flight for this user.
      Oban.insert!(Jobs.Ebird.Import.new(%{user_id: user.id, upload_key: "in-flight"}))

      file =
        file_input(lv, "#ebird-csv-import-form", :ebird_zip, [
          %{name: "MyEBirdData.zip", content: csv_zip(), type: "application/zip"}
        ])

      assert render_upload(file, "MyEBirdData.zip") =~ "MyEBirdData.zip"
      html = lv |> element("#ebird-csv-import-form") |> render_submit()

      assert html =~ "An eBird import is already in progress."

      # The exclusive job wasn't duplicated: only the original in-flight one.
      assert [%Oban.Job{args: %{"upload_key" => "in-flight"}}] =
               Oban.Job |> Kjogvi.Repo.all(prefix: Oban.config().prefix)

      # The rejected upload was deleted, not orphaned: no stored uploads remain
      # for this user (the "in-flight" key was never actually stored).
      assert stored_ebird_uploads(user) == []
    end

    defp stored_ebird_uploads(user) do
      config = Application.get_env(:kjogvi, Kjogvi.Imports.Upload)
      dir = Path.join([Keyword.fetch!(config, :path), "imports", "ebird", to_string(user.id)])

      case File.ls(dir) do
        {:ok, files} -> files
        {:error, :enoent} -> []
      end
    end

    test "a progress message is routed to the CSV import component", %{lv: lv, user: user} do
      broadcast_progress({:ebird_import, user.id}, %{message: "Unpacking export..."})

      assert flush_render(lv) =~ "Unpacking export..."
    end
  end

  describe "import status" do
    setup do
      %{user: Kjogvi.AccountsFixtures.user_fixture()}
    end

    test "shows nothing for a user who has never imported", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      # The panel's container is always present; it just has nothing to report.
      assert has_element?(lv, "#ebird-csv-import-status")
      refute render(lv) =~ "Import complete"
      refute render(lv) =~ "Import failed"

      # The full run-by-run history is admin-only now.
      refute has_element?(lv, "#import-history")
    end

    test "reports the outcome and counts of the user's last run, not another user's",
         %{conn: conn, user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()
      {:ok, other_log} = Imports.enqueue_ebird_import(other_user, "other.zip")
      Imports.log_completed(other_log.id, :completed, %{checklists_created: 99})

      {:ok, log} = Imports.enqueue_ebird_import(user, "mine.zip")

      Imports.log_completed(log.id, :completed_with_errors, %{
        checklists_created: 3,
        observations_created: 12,
        checklists_unmapped: 2,
        unresolved_taxa: ["Bogus specius"]
      })

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      html = render(lv)
      assert html =~ "Import finished with issues"
      assert html =~ "3 checklists and 12 observations imported"
      assert html =~ "2 checklists not imported"
      assert html =~ "1 taxon unrecognized"

      refute html =~ "99 checklists"
    end

    test "only the latest run is reported", %{conn: conn, user: user} do
      {:ok, older} = Imports.enqueue_ebird_import(user, "older.zip")
      Imports.log_failed(older.id, "An older failure nobody needs to see.")

      # The job is exclusive per user across the incomplete states, so the
      # first run's row has to leave them before a second can be enqueued.
      Oban.cancel_all_jobs(Oban.Job)

      {:ok, newer} = Imports.enqueue_ebird_import(user, "newer.zip")
      Imports.log_completed(newer.id, :completed, %{checklists_created: 1})

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      html = render(lv)
      assert html =~ "Import complete"
      refute html =~ "An older failure nobody needs to see."
    end

    test "a failed run shows its reason", %{conn: conn, user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "mine.zip")
      Imports.log_failed(log.id, "The export contained no CSV file.")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      html = render(lv)
      assert html =~ "Import failed"
      assert html =~ "The export contained no CSV file."
    end

    test "an in-progress run shows a spinner and its message, not the info icon",
         %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      broadcast_progress({:ebird_import, user.id}, %{message: "Importing checklists..."})

      html = flush_render(lv)
      assert html =~ "Importing checklists..."

      assert has_element?(lv, "#ebird-csv-import-status .animate-spin")
      refute has_element?(lv, "#ebird-csv-import-status .hero-information-circle-mini")
    end

    test "a lifecycle broadcast refreshes the reported outcome", %{conn: conn, user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "mine.zip")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      # A pending job slot reports itself as running, spinner and all.
      assert render(lv) =~ "eBird import in progress..."
      assert has_element?(lv, "#ebird-csv-import-status .animate-spin")

      # Simulates what the LogRecorder does before the Bridge broadcast fires.
      Imports.log_completed(log.id, :completed, %{
        checklists_created: 1,
        observations_created: 1
      })

      broadcast_lifecycle(
        {:ebird_import, user.id},
        :ok,
        AsyncResult.ok(AsyncResult.loading(%{}), %{message: "Done."})
      )

      html = flush_render(lv)
      assert html =~ "Import complete"
      assert html =~ "1 checklist and 1 observation imported"
    end

    test "a crash with nothing recorded on the log still reports a failure",
         %{conn: conn, user: user} do
      {:ok, _log} = Imports.enqueue_ebird_import(user, "mine.zip")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/ebird")

      broadcast_lifecycle(
        {:ebird_import, user.id},
        :error,
        AsyncResult.failed(%AsyncResult{}, :timeout)
      )

      assert flush_render(lv) =~ "The import timed out."
    end
  end
end
