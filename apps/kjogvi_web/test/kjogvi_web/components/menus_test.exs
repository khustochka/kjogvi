defmodule KjogviWeb.MenusTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  describe "private menu" do
    test "shows personal links for a logged-in user", %{conn: conn} do
      conn = login_user(conn, user_fixture())

      {:ok, live, _html} = live(conn, ~p"/my/locations")

      assert has_element?(live, "#private-menu a[href='/my/checklists']", "Checklists")
      assert has_element?(live, "#private-menu a[href='/my/imports']", "Imports")
    end

    test "carries no admin links", %{conn: conn} do
      conn = login_user(conn, admin_fixture())

      {:ok, live, _html} = live(conn, ~p"/my/locations")

      refute has_element?(live, "#private-menu a[href='/admin/locations']")
      refute has_element?(live, "#private-menu a[href='/admin/taxonomy']")
    end

    test "is absent for a guest", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/community/lifelist")

      refute has_element?(live, "#private-menu")
    end
  end

  describe "admin menu" do
    test "shows admin links for an admin", %{conn: conn} do
      conn = login_user(conn, admin_fixture())

      {:ok, live, _html} = live(conn, ~p"/my/locations")

      assert has_element?(live, "#admin-menu a[href='/admin/locations']", "Locations")
      assert has_element?(live, "#admin-menu a[href='/admin/imports']", "Imports")
      assert has_element?(live, "#admin-menu a[href='/admin/taxonomy']", "Taxonomy")
      assert has_element?(live, "#admin-menu a[href='/admin/oban']", "Oban")
      assert has_element?(live, "#admin-menu a[href='/admin/dashboard']", "Live Dashboard")
    end

    test "shows on public pages too", %{conn: conn} do
      conn = login_user(conn, admin_fixture())

      {:ok, live, _html} = live(conn, ~p"/community/lifelist")

      assert has_element?(live, "#admin-menu a[href='/admin/locations']")
    end

    test "is absent for a regular user", %{conn: conn} do
      conn = login_user(conn, user_fixture())

      {:ok, live, _html} = live(conn, ~p"/my/locations")

      refute has_element?(live, "#admin-menu")
    end
  end
end
