defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  @moduletag :capture_log

  import Phoenix.LiveViewTest

  alias Kjogvi.Jobs
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  defp flush_render(lv) do
    _ = render(lv)
    render(lv)
  end

  describe "page rendering" do
    test "an admin sees the Legacy import", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.admin_fixture())
        |> live(~p"/my/imports")

      assert html =~ "Import Tasks"
      assert html =~ "Legacy Import"
      # The ISO locations import lives on /admin/imports/locations now.
      refute html =~ "Locations Import"
    end

    test "a non-admin user does not see the legacy import", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.user_fixture())
        |> live(~p"/my/imports")

      assert html =~ "Import Tasks"
      refute html =~ "Legacy Import"
    end

    test "does not show the import history", %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()
      {:ok, _log} = Kjogvi.Imports.enqueue_ebird_import(user, "mine.zip")

      {:ok, lv, _html} =
        conn
        |> login_user(user)
        |> live(~p"/my/imports")

      refute has_element?(lv, "#import-history")
    end

    test "redirects when not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/imports")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/account/login"
    end
  end

  # The import runs as an exclusive Oban job: a running job broadcasts
  # `{:progress, key, %{message: ...}}` on the key's PubSub topic, and the
  # matching component (subscribed on mount) renders the latest status as a
  # loading info flash.
  defp broadcast_progress(key, data) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:progress, key, data}
    )
  end

  # When a job finishes, Kjogvi.Jobs.Runtime.Bridge broadcasts a lifecycle event
  # carrying the outcome as an AsyncResult.
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

  describe "legacy taxonomy note" do
    defp mount_imports(conn, attrs) do
      {:ok, lv, _html} =
        conn
        |> login_user(Kjogvi.AccountsFixtures.admin_fixture(attrs))
        |> live(~p"/my/imports")

      lv
    end

    test "warns when the import will switch the user's taxonomy", %{conn: conn} do
      lv = mount_imports(conn, %{default_book_signature: "ebird/v2025"})

      assert has_element?(
               lv,
               "#legacy-import-taxonomy-note",
               "from ebird/v2025 to #{Kjogvi.Legacy.Import.book_signature()}"
             )
    end

    test "says the taxonomy will be set when the user has none", %{conn: conn} do
      lv = mount_imports(conn, %{default_book_signature: nil})

      assert has_element?(lv, "#legacy-import-taxonomy-note", "will set your default taxonomy")
    end

    test "is absent when the user already has the legacy taxonomy", %{conn: conn} do
      lv = mount_imports(conn, %{default_book_signature: Kjogvi.Legacy.Import.book_signature()})

      refute has_element?(lv, "#legacy-import-taxonomy-note")
    end

    test "disappears after a successful import", %{conn: conn} do
      user = Kjogvi.AccountsFixtures.admin_fixture(%{default_book_signature: "ebird/v2025"})
      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/imports")

      broadcast_lifecycle(
        {:legacy_import, user.id},
        :ok,
        AsyncResult.ok(%{message: "Legacy import done."})
      )

      _ = flush_render(lv)
      refute has_element?(lv, "#legacy-import-taxonomy-note")
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

    # The legacy taxonomy isn't loaded in the test DB, so the run fails; the
    # error travels job -> bridge -> PubSub -> component flash.
    test "a failed run surfaces the error", %{lv: lv} do
      lv |> element("#legacy-import-form") |> render_submit()

      assert %{discard: 1} = Oban.drain_queue(queue: :imports)

      assert flush_render(lv) =~
               "Legacy import failed: Legacy import requires the ebird/v2026 taxonomy."
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
end
