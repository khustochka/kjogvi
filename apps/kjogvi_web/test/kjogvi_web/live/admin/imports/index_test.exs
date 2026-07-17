defmodule KjogviWeb.Live.Admin.Imports.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/imports")

    assert response(conn, 404)
  end

  describe "page rendering" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows the heading", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      assert has_element?(lv, "h1", "Imports")
    end

    test "links to the location imports workbench", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/imports")

      assert has_element?(lv, "a[href='/admin/imports/locations']", "Location Imports")
    end
  end
end
