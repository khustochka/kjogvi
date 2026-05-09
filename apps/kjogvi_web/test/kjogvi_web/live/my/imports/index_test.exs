defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias KjogviWeb.Live.My.Imports

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

  describe "registry routes task results to the correct child" do
    setup %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(Kjogvi.UsersFixtures.user_fixture())
        |> live(~p"/my/imports")

      %{lv: lv}
    end

    test "{ref, {:ok, data}} routes to the registered Legacy component", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Legacy, "legacy-import", ref})
      send(lv.pid, {ref, {:ok, %{message: "Legacy done."}}})

      assert flush_render(lv) =~ "Legacy done."
    end

    test "{ref, {:error, data}} routes an error flash to the registered child", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Legacy, "legacy-import", ref})
      send(lv.pid, {ref, {:error, %{message: "boom"}}})

      assert flush_render(lv) =~ "Legacy import failed: boom"
    end

    test "{:DOWN, ref, ...} for a registered ref produces a server error flash", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Legacy, "legacy-import", ref})
      fake_pid = spawn(fn -> :ok end)
      send(lv.pid, {:DOWN, ref, :process, fake_pid, :killed})

      assert flush_render(lv) =~ "Legacy import failed: Server error."
    end

    test "an unregistered ref is ignored without crashing", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {ref, {:ok, %{message: "should not appear"}}})

      html = flush_render(lv)
      refute html =~ "should not appear"
      assert Process.alive?(lv.pid)
    end

    test "after a result is delivered, the ref is dropped from the registry", %{lv: lv} do
      ref = make_ref()
      send(lv.pid, {:register_import, Imports.Legacy, "legacy-import", ref})
      send(lv.pid, {ref, {:ok, %{message: "first"}}})
      _ = flush_render(lv)

      send(lv.pid, {ref, {:ok, %{message: "second"}}})
      html = flush_render(lv)

      refute html =~ "second"
    end
  end

  describe "progress hook" do
    setup %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> log_in_user(Kjogvi.UsersFixtures.user_fixture())
        |> live(~p"/my/imports")

      %{lv: lv}
    end

    test "Legacy progress message is routed to the Legacy component", %{lv: lv} do
      send(lv.pid, {:legacy_import_progress, %{message: "step 1"}})
      assert flush_render(lv) =~ "step 1"
    end

    test "eBird progress message is routed to the eBird component", %{lv: lv} do
      send(lv.pid, {:ebird_preload_progress, %{message: "fetching"}})
      assert flush_render(lv) =~ "fetching"
    end
  end
end
