defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kjogvi.Store
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
        |> log_in_user(Kjogvi.AccountsFixtures.user_fixture())
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

  # Both imports use the ExclusiveTaskProcessor: a running task broadcasts
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

  # When a task finishes, the ExclusiveTaskProcessor broadcasts a lifecycle event
  # carrying the AsyncResult as stored. The eBird component reacts to `:ok` by
  # refreshing its display from the store (which the task itself populated) and
  # surfacing a count flash.
  defp broadcast_lifecycle(key, event, async_result) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      PubSubTopic.for_key(key),
      {:lifecycle, event, key, async_result}
    )
  end

  describe "legacy progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
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
  end

  describe "eBird progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.AccountsFixtures.user_fixture()

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
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

    # End-to-end failure path: a user without eBird credentials makes the task
    # return `{:error, _}`. The task closure must not store anything, and the
    # processor's `:error` lifecycle must surface a failure flash.
    test "on failure nothing is stored and an error flash is shown",
         %{conn: conn} do
      # A bare fixture has no eBird username/password configured.
      user = Kjogvi.AccountsFixtures.user_fixture()
      key = {:ebird_preload, user.id}

      # Subscribe first so we can deterministically wait for the task to finish
      # instead of polling.
      Phoenix.PubSub.subscribe(Kjogvi.PubSub, PubSubTopic.for_key(key))

      {:ok, lv, _html} =
        conn
        |> log_in_user(user)
        |> live(~p"/my/imports")

      lv
      |> element("form[phx-submit='start_preload']")
      |> render_submit()

      assert_receive {:lifecycle, :error, ^key, _async_result}, 2_000

      html = flush_render(lv)
      assert html =~ "eBird preload failed: User does not have eBird configuration."
      assert Store.ChecklistPreload.get_preloads(user).checklists == []
    end
  end
end
