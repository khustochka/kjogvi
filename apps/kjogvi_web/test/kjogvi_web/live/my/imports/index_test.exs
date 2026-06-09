defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.My.Imports
  alias Kjogvi.Util.AsyncResult
  alias Kjogvi.Util.PubSubTopic

  defp flush_render(lv) do
    _ = render(lv)
    render(lv)
  end

  describe "page rendering" do
    test "renders both import cards", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(Kjogvi.UsersFixtures.user_fixture())
        |> live(~p"/my/imports")

      assert html =~ "Import Tasks"
      assert html =~ "Legacy Import"
      assert html =~ "eBird preload"
    end

    test "redirects when not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/imports")
      assert {:redirect, %{to: path}} = redirect
      assert path == ~p"/users/log_in"
    end
  end

  # The eBird import still uses the Registry plumbing: a child component starts a
  # `Task.Supervisor.async_nolink` task, registers its ref with the LiveView, and
  # the Registry hook routes the `{ref, result}` / `{:DOWN, ref, ...}` messages
  # back to the registered child via `send_update/2`.
  describe "registry routes task results to the correct child" do
    setup %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(Kjogvi.UsersFixtures.user_fixture())
        |> live(~p"/my/imports")

      %{lv: lv}
    end

    test "{ref, {:ok, data}} routes to the registered eBird component", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Ebird, "ebird-import", ref})
      send(lv.pid, {ref, {:ok, []}})

      assert flush_render(lv) =~ "eBird preload done: 0 new checklists."
    end

    test "{ref, {:error, data}} routes an error flash to the registered child", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Ebird, "ebird-import", ref})
      send(lv.pid, {ref, {:error, %{message: "boom"}}})

      assert flush_render(lv) =~ "eBird preload failed: boom"
    end

    test "{:DOWN, ref, ...} for a registered ref produces a server error flash", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Ebird, "ebird-import", ref})
      fake_pid = spawn(fn -> :ok end)
      send(lv.pid, {:DOWN, ref, :process, fake_pid, :killed})

      assert flush_render(lv) =~ "eBird preload failed: Server error."
    end

    test "an unregistered ref is ignored without crashing", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {ref, {:ok, []}})

      html = flush_render(lv)
      refute html =~ "eBird preload done"
      assert Process.alive?(lv.pid)
    end

    test "after a result is delivered, the ref is dropped from the registry", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Ebird, "ebird-import", ref})
      send(lv.pid, {ref, {:error, %{message: "first"}}})
      _ = flush_render(lv)

      send(lv.pid, {ref, {:error, %{message: "second"}}})
      html = flush_render(lv)

      refute html =~ "second"
    end
  end

  # The Legacy import uses the ExclusiveTaskProcessor: the running task
  # broadcasts `{:progress, {:legacy_import, user_id}, async_result}` on the
  # key's PubSub topic, and the Legacy component (subscribed on mount) renders
  # the latest status.
  describe "legacy progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.UsersFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my/imports")

      %{lv: lv, user: user}
    end

    defp broadcast_legacy(user, async_result) do
      key = {:legacy_import, user.id}

      Phoenix.PubSub.broadcast(
        Kjogvi.PubSub,
        PubSubTopic.for_key(key),
        {:progress, key, async_result}
      )
    end

    test "a loading progress message is rendered by the Legacy component", %{lv: lv, user: user} do
      broadcast_legacy(user, AsyncResult.loading(%{message: "Importing locations... 42"}))

      assert flush_render(lv) =~ "Importing locations... 42"
    end

    test "a successful result is rendered by the Legacy component", %{lv: lv, user: user} do
      broadcast_legacy(user, AsyncResult.ok(%{message: "Legacy import done."}))

      assert flush_render(lv) =~ "Legacy import done."
    end

    test "a failed result is rendered as an error by the Legacy component", %{lv: lv, user: user} do
      broadcast_legacy(user, AsyncResult.failed(%AsyncResult{}, %{message: "boom"}))

      assert flush_render(lv) =~ "Legacy import failed: boom"
    end
  end

  describe "eBird progress hook" do
    setup %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(Kjogvi.UsersFixtures.user_fixture())
        |> live(~p"/my/imports")

      %{lv: lv}
    end

    test "eBird progress message is routed to the eBird component", %{lv: lv} do
      send(lv.pid, {:ebird_preload_progress, %{message: "fetching"}})
      assert flush_render(lv) =~ "fetching"
    end
  end
end
