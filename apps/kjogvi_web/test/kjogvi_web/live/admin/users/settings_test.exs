defmodule KjogviWeb.Live.Admin.Users.SettingsTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Accounts

  test "returns 404 for a non-admin user" do
    target = user_fixture()

    conn =
      build_conn()
      |> login_user(user_fixture())
      |> get(~p"/admin/users/#{target.id}/settings")

    assert response(conn, 404)
  end

  describe "settings" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows the user and their login state", %{conn: conn} do
      user = user_fixture(nickname: "birder")

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user.id}/settings")

      assert has_element?(lv, "h1", "User Settings")
      assert has_element?(lv, "#login-state", "Login enabled")
      assert has_element?(lv, "#toggle-login", "Disable login")
    end

    test "reflects an already-disabled user", %{conn: conn} do
      user = user_fixture()
      Accounts.disable_user_login(user)

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user.id}/settings")

      assert has_element?(lv, "#login-state", "Login disabled")
      assert has_element?(lv, "#toggle-login", "Enable login")
    end

    test "disabling login bars the user", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user.id}/settings")

      lv |> element("#toggle-login") |> render_click()

      assert has_element?(lv, "#login-state", "Login disabled")
      assert Accounts.login_disabled?(Accounts.get_user!(user.id))
    end

    test "enabling login restores the user", %{conn: conn} do
      user = user_fixture()
      Accounts.disable_user_login(user)

      {:ok, lv, _html} = live(conn, ~p"/admin/users/#{user.id}/settings")

      lv |> element("#toggle-login") |> render_click()

      assert has_element?(lv, "#login-state", "Login enabled")
      refute Accounts.login_disabled?(Accounts.get_user!(user.id))
    end
  end
end
