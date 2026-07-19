defmodule KjogviWeb.Live.Admin.Users.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/users")

    assert response(conn, 404)
  end

  describe "index" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "lists all users", %{conn: conn} do
      alice = user_fixture(nickname: "alice", display_name: "Alice Smith")
      bob = user_fixture(nickname: "bob")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      assert has_element?(lv, "h1", "Users")
      assert has_element?(lv, "#user-#{alice.id}", "alice")
      assert has_element?(lv, "#user-#{alice.id}", "Alice Smith")
      assert has_element?(lv, "#user-#{bob.id}", "bob")
    end

    test "each row links to the user's settings page", %{conn: conn} do
      alice = user_fixture(nickname: "alice")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      assert has_element?(
               lv,
               "#user-#{alice.id} a[href='/admin/users/#{alice.id}/settings']"
             )
    end

    test "shows the total user count", %{conn: conn} do
      before = Kjogvi.Accounts.count_users()
      user_fixture()
      user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      assert has_element?(lv, "#users-count", to_string(before + 2))
    end

    test "marks users whose login is disabled with a lock", %{conn: conn} do
      disabled = user_fixture(nickname: "barred")
      active = user_fixture(nickname: "active")
      Kjogvi.Accounts.disable_user_login(disabled)

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      assert has_element?(lv, "#user-#{disabled.id} [aria-label='Login disabled']")
      refute has_element?(lv, "#user-#{active.id} [aria-label='Login disabled']")
    end

    test "marks admin users", %{conn: conn} do
      admin = admin_fixture(nickname: "chief")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      assert has_element?(lv, "#user-#{admin.id}", "Admin")
    end

    test "searches by nickname", %{conn: conn} do
      alice = user_fixture(nickname: "alice")
      bob = user_fixture(nickname: "bob")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv
      |> element("#user-search")
      |> render_keyup(%{"value" => "ali"})

      assert has_element?(lv, "#user-#{alice.id}")
      refute has_element?(lv, "#user-#{bob.id}")
    end

    test "searches by display name", %{conn: conn} do
      alice = user_fixture(nickname: "alice", display_name: "Wonderland")
      bob = user_fixture(nickname: "bob", display_name: "Builder")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv
      |> element("#user-search")
      |> render_keyup(%{"value" => "wonder"})

      assert has_element?(lv, "#user-#{alice.id}")
      refute has_element?(lv, "#user-#{bob.id}")
    end

    test "clearing the search restores the full list", %{conn: conn} do
      alice = user_fixture(nickname: "alice")
      bob = user_fixture(nickname: "bob")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv |> element("#user-search") |> render_keyup(%{"value" => "ali"})
      refute has_element?(lv, "#user-#{bob.id}")

      lv |> element("button[phx-click='clear_user_filter']") |> render_click()

      assert has_element?(lv, "#user-#{alice.id}")
      assert has_element?(lv, "#user-#{bob.id}")
    end

    test "shows an empty state when a search matches nothing", %{conn: conn} do
      user_fixture(nickname: "alice")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv |> element("#user-search") |> render_keyup(%{"value" => "zzzzz"})

      assert has_element?(lv, "p", "No users found")
    end

    test "searching updates the URL so the view is linkable", %{conn: conn} do
      alice = user_fixture(nickname: "alice")

      {:ok, lv, _html} = live(conn, ~p"/admin/users")

      lv |> element("#user-search") |> render_keyup(%{"value" => "ali"})

      assert_patch(lv, ~p"/admin/users?q=ali")

      # Re-entering by the resulting URL renders the filtered list directly.
      {:ok, lv2, _html} = live(conn, ~p"/admin/users?q=ali")
      assert has_element?(lv2, "#user-search[value='ali']")
      assert has_element?(lv2, "#user-#{alice.id}")
    end

    test "paginates, preserving the search term in page links", %{conn: conn} do
      for n <- 1..51, do: user_fixture(nickname: "birder#{String.pad_leading("#{n}", 3, "0")}")

      {:ok, lv, _html} = live(conn, ~p"/admin/users?q=birder")

      # 51 matches over a 50-per-page window: a second page exists and its link
      # carries the search term.
      assert has_element?(lv, "a[href='/admin/users/page/2?q=birder']")
    end
  end
end
