defmodule KjogviWeb.Live.My.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

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

  describe "legacy progress over PubSub" do
    setup %{conn: conn} do
      user = Kjogvi.UsersFixtures.user_fixture()

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
      user = Kjogvi.UsersFixtures.user_fixture()

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
  end
end
