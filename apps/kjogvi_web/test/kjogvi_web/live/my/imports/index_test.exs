defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  @moduletag :capture_log

  import Phoenix.LiveViewTest

  alias Kjogvi.Jobs
  alias Kjogvi.Store
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  defp flush_render(lv) do
    _ = render(lv)
    render(lv)
  end

  describe "page rendering" do
    test "an admin sees both the Legacy and eBird import checklists", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.admin_fixture())
        |> live(~p"/my/imports")

      assert html =~ "Import Tasks"
      assert html =~ "Legacy Import"
      assert html =~ "eBird preload"
      assert html =~ "eBird CSV import"
      # The ISO locations import lives on /admin/imports/locations now.
      refute html =~ "Locations Import"
    end

    test "a non-admin user sees the eBird import checklists but not the legacy one",
         %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.user_fixture())
        |> live(~p"/my/imports")

      assert html =~ "Import Tasks"
      assert html =~ "eBird preload"
      assert html =~ "eBird CSV import"
      refute html =~ "Legacy Import"
    end

    test "redirects when not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/imports")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/account/login"
    end
  end

  # Both imports run as exclusive Oban jobs: a running job broadcasts
  # `{:progress, key, %{message: ...}}` on the key's PubSub topic, and the
  # matching component (subscribed on mount) renders the latest status as a
  # loading info flash. The key tags the broadcast so it reaches the right
  # component.
  defp broadcast_progress(key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:progress, key, data}
    )
  end

  # When a job finishes, Kjogvi.Jobs.Runtime.Bridge broadcasts a lifecycle event
  # carrying the outcome as an AsyncResult. The eBird component reacts to `:ok`
  # by refreshing its display from the store (which the job itself populated)
  # and surfacing a count flash.
  defp broadcast_lifecycle(key, event, async_result) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:lifecycle, event, key, async_result}
    )
  end

  describe "legacy progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.admin_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    test "a progress message is rendered by the Legacy component", %{lv: lv, user: user} do
      broadcast_progress({:legacy_import, user.id}, %{message: "Importing locations... 42"})

      assert flush_render(lv) =~ "Importing locations... 42"
    end

    test "the done message is rendered by the Legacy component", %{lv: lv, user: user} do
      broadcast_progress({:legacy_import, user.id}, %{message: "Legacy import done."})

      assert flush_render(lv) =~ "Legacy import done."
    end

    test "a non-admin's session ignores legacy progress broadcasts", %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      broadcast_progress({:legacy_import, user.id}, %{message: "Importing locations... 42"})

      refute flush_render(lv) =~ "Importing locations... 42"
    end
  end

  describe "starting the legacy import" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.admin_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    test "enqueues the job and disables the button", %{lv: lv, user: user} do
      lv |> element("#legacy-import-form") |> render_submit()

      assert has_element?(lv, "#legacy-import-form button[disabled]")
      assert render(lv) =~ "Legacy import in progress..."

      assert %AsyncResult{loading: %{message: _}} =
               Jobs.status(Jobs.LegacyImport, %{user_id: user.id})
    end

    # An admin without a default taxonomy makes the run fail; the error
    # travels job -> bridge -> PubSub -> component flash.
    test "a failed run surfaces the error", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.admin_fixture(%{default_book_signature: nil}))
        |> live(~p"/my/imports")

      lv |> element("#legacy-import-form") |> render_submit()

      assert %{discard: 1} = Oban.drain_queue(queue: :imports)

      assert flush_render(lv) =~
               "Legacy import failed: Legacy import requires a default taxonomy."
    end

    test "a second start while a run is pending does not enqueue another job", %{lv: lv} do
      lv |> element("#legacy-import-form") |> render_submit()
      # The button is disabled once a run is pending; fire the submit again
      # directly to simulate a second session racing it.
      lv |> element("#legacy-import-form") |> render_submit()

      assert %{discard: 1} = Oban.drain_queue(queue: :imports)
      # Sync with the LiveView so it finishes handling the completion
      # broadcast before the test process exits and kills it mid-query.
      render(lv)
    end

    test "a pending run is visible to a freshly mounted page", %{lv: lv, user: user} do
      lv |> element("#legacy-import-form") |> render_submit()

      {:ok, lv2, _html} =
        build_conn()
        |> login_user(user)
        |> live(~p"/my/imports")

      assert has_element?(lv2, "#legacy-import-form button[disabled]")
      assert render(lv2) =~ "Legacy import in progress..."
    end

    # Progress recorded on the job row (Kjogvi.Jobs.progress/2) seeds a fresh
    # mount, so a mid-run page load shows where the run is, not just that it
    # is in progress.
    test "a freshly mounted page shows the run's recorded progress", %{user: user} do
      # Read the job back so it has the JSON string-keyed args of the real flow.
      job = Oban.insert!(Jobs.LegacyImport.new(%{user_id: user.id}))
      job = Kjogvi.Repo.get!(Oban.Job, job.id, prefix: Oban.config().prefix)
      Jobs.progress(job, %{message: "Importing observations... 4200"})

      {:ok, lv2, _html} =
        build_conn()
        |> login_user(user)
        |> live(~p"/my/imports")

      assert has_element?(lv2, "#legacy-import-form button[disabled]")
      assert render(lv2) =~ "Importing observations... 4200"
    end
  end

  describe "starting the eBird preload" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, _user} =
        Kjogvi.Accounts.update_user_preferences(user, %{
          preferences: %{ebird: %{username: "birder", password: "secret"}}
        })

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    # The run itself would hit the eBird site, so it is never drained here —
    # these tests stop at the enqueued job.
    test "enqueues the job, resets stored preloads, and disables the button",
         %{lv: lv, user: user} do
      Store.ChecklistPreload.store_checklists(user, [
        %{ebird_id: "S1", date: ~D[2026-06-01], time: ~T[07:30:00], location: "Central Park"}
      ])

      lv |> element("#ebird-preload-form") |> render_submit()

      assert has_element?(lv, "#ebird-preload-form button[disabled]")
      assert render(lv) =~ "eBird preload in progress..."

      assert %AsyncResult{loading: %{message: _}} =
               Jobs.status(Jobs.EbirdPreload, %{user_id: user.id})

      assert Store.ChecklistPreload.get_preloads(user).checklists == []
    end
  end

  describe "eBird progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    test "a progress message is routed to the eBird component", %{lv: lv, user: user} do
      broadcast_progress({:ebird_preload, user.id}, %{message: "Logging in..."})

      assert flush_render(lv) =~ "Logging in..."
    end

    # The task persists checklists to the store and its result carries only the
    # completion message. On the `:ok` lifecycle the component renders the
    # checklists straight from the store and surfaces the message from the result.
    test "on success the eBird component renders stored checklists and the message",
         %{lv: lv, user: user} do
      checklists = [
        %{ebird_id: "S1", date: ~D[2026-06-01], time: ~T[07:30:00], location: "Central Park"},
        %{ebird_id: "S2", date: ~D[2026-06-02], time: ~T[08:00:00], location: "Prospect Park"}
      ]

      # Simulates what the task does in the background before completing: persist
      # the checklists, then finish carrying just the message.
      Store.ChecklistPreload.store_checklists(user, checklists)

      key = {:ebird_preload, user.id}

      async_result =
        AsyncResult.ok(
          AsyncResult.loading(%{}),
          %{message: "eBird preload done: 2 new checklists."}
        )

      broadcast_lifecycle(key, :ok, async_result)

      html = flush_render(lv)

      assert html =~ "eBird preload done: 2 new checklists."
      assert html =~ "Central Park"
      assert html =~ "Prospect Park"
    end

    # Failure path: a user without eBird credentials never enqueues the job —
    # the error is surfaced immediately and nothing is stored.
    test "on missing eBird configuration nothing is enqueued or stored and an error flash is shown",
         %{conn: conn} do
      # A bare fixture has no eBird username/password configured.
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      html =
        lv
        |> element("form[phx-submit='start_preload']")
        |> render_submit()

      assert html =~ "eBird preload failed: User does not have eBird configuration."
      assert Store.ChecklistPreload.get_preloads(user).checklists == []
      assert Jobs.status(Jobs.EbirdPreload, %{user_id: user.id}) == %AsyncResult{}
    end
  end

  describe "eBird CSV import" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    defp csv_zip do
      {:ok, {_name, bin}} =
        :zip.create(~c"export.zip", [{~c"MyEBirdData.csv", "Row ID,Common Name\n1,Mallard\n"}], [
          :memory
        ])

      bin
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

  describe "import history" do
    alias Kjogvi.Imports

    setup do
      %{user: Kjogvi.AccountsFixtures.user_fixture()}
    end

    test "shows an empty state without any runs", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      assert has_element?(lv, "#import-history")
      assert render(lv) =~ "No imports yet"
    end

    test "lists the user's runs with status and counts, not other users'",
         %{conn: conn, user: user} do
      other_user = Kjogvi.AccountsFixtures.user_fixture()
      {:ok, other_log} = Imports.enqueue_ebird_import(other_user, "other.zip")

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
        |> live(~p"/my/imports")

      assert has_element?(lv, "#import-log-#{log.id}")
      refute has_element?(lv, "#import-log-#{other_log.id}")

      html = render(lv)
      assert html =~ "Completed with issues"
      assert html =~ "3 checklists and 12 observations imported"
      assert html =~ "2 checklists not imported"
      assert html =~ "1 taxon unrecognized"
    end

    test "a failed run shows its error", %{conn: conn, user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "mine.zip")
      Imports.log_failed(log.id, "The export contained no CSV file.")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      assert has_element?(lv, "#import-log-#{log.id}")

      html = render(lv)
      assert html =~ "Failed"
      assert html =~ "The export contained no CSV file."
    end

    test "starting a CSV import adds a queued run to the history", %{conn: conn, user: user} do
      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      file =
        file_input(lv, "#ebird-csv-import-form", :ebird_zip, [
          %{name: "MyEBirdData.zip", content: csv_zip(), type: "application/zip"}
        ])

      render_upload(file, "MyEBirdData.zip")
      lv |> element("#ebird-csv-import-form") |> render_submit()

      [log] = Imports.list_import_logs(user)
      assert has_element?(lv, "#import-log-#{log.id}")
      assert render(lv) =~ "Queued"
    end

    test "a lifecycle broadcast refreshes the history", %{conn: conn, user: user} do
      {:ok, log} = Imports.enqueue_ebird_import(user, "mine.zip")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      assert render(lv) =~ "Queued"

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
      assert html =~ "Completed"
      assert html =~ "1 checklist and 1 observation imported"
    end
  end
end
