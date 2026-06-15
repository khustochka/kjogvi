defmodule KjogviWeb.Live.Admin.ExclusiveTasks.IndexTest do
  use KjogviWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Kjogvi.Server.ExclusiveTaskProcessor
  alias Kjogvi.Util.AsyncResult

  # Pushes a lifecycle event onto the global topic the dashboard subscribes to,
  # exactly as the processor would, so we can drive the live page without running
  # a real task. Uses a unique key per test to avoid bleed across the shared
  # singleton's topic.
  defp broadcast_lifecycle(event, key, async_result) do
    Phoenix.PubSub.broadcast(
      Kjogvi.PubSub,
      ExclusiveTaskProcessor.lifecycle_topic(),
      {:lifecycle, event, key, async_result}
    )
  end

  # Mirrors the DOM id the LiveView renders: the sanitized key (`:` is not
  # CSS-safe), prefixed by the `tasks` stream name.
  defp dom_id(key) do
    "tasks-" <> String.replace(Kjogvi.Util.PubSubTopic.for_key(key), ~r/[^A-Za-z0-9_-]/, "-")
  end

  setup %{conn: conn} do
    %{conn: login_user(conn, Kjogvi.AccountsFixtures.admin_fixture())}
  end

  describe "page rendering" do
    test "renders the heading", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/admin/exclusive-tasks")
      assert html =~ "Exclusive Tasks"
    end

    test "shows the empty state when no tasks are tracked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/exclusive-tasks")
      assert has_element?(lv, "#exclusive-tasks-empty")
    end

    test "is not found for a non-admin user" do
      conn = login_user(build_conn(), Kjogvi.AccountsFixtures.user_fixture())

      assert_error_sent :not_found, fn ->
        live(conn, ~p"/admin/exclusive-tasks")
      end
    end
  end

  describe "live updates over the lifecycle topic" do
    setup %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/exclusive-tasks")
      %{lv: lv}
    end

    test "a started task appears as a running row", %{lv: lv} do
      key = {:dashboard_test_start, 1}
      broadcast_lifecycle(:start, key, AsyncResult.loading(%{message: "warming up"}))

      assert has_element?(lv, "##{dom_id(key)}", "warming up")
      assert has_element?(lv, "##{dom_id(key)}", "RUNNING")
    end

    test "a completed task updates the same row in place", %{lv: lv} do
      key = {:dashboard_test_done, 1}

      broadcast_lifecycle(:start, key, AsyncResult.loading(%{message: "in progress"}))
      assert has_element?(lv, "##{dom_id(key)}", "in progress")

      broadcast_lifecycle(:ok, key, AsyncResult.ok(%{message: "all done"}))

      assert has_element?(lv, "##{dom_id(key)}", "all done")
      assert has_element?(lv, "##{dom_id(key)}", "OK")
    end

    test "a finish time appears only once the task completes", %{lv: lv} do
      key = {:dashboard_test_finished_at, 1}

      broadcast_lifecycle(:start, key, AsyncResult.loading(%{message: "running"}))
      refute has_element?(lv, "##{dom_id(key)} time")

      broadcast_lifecycle(:ok, key, AsyncResult.ok(%{message: "done"}))
      assert has_element?(lv, "##{dom_id(key)} time")
    end

    test "a failed task shows the raw failure reason", %{lv: lv} do
      key = {:dashboard_test_fail, 1}
      broadcast_lifecycle(:error, key, AsyncResult.failed(%AsyncResult{}, :timeout))

      assert has_element?(lv, "##{dom_id(key)}", ":timeout")
      assert has_element?(lv, "##{dom_id(key)}", "FAILED")
    end

    test "the full term is rendered (hidden) for click-to-expand", %{lv: lv} do
      key = {:dashboard_test_rich, 1}
      broadcast_lifecycle(:ok, key, AsyncResult.ok(%AsyncResult{}, %{imported: 42, skipped: 3}))

      # The pretty-inspected term lives in the hidden -full element so JS.toggle
      # can reveal it client-side without a server round-trip.
      assert lv
             |> element("##{dom_id(key)}-full")
             |> render() =~ "imported: 42"
    end
  end
end
