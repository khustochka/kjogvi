defmodule KjogviWeb.Live.Admin.Settings.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Settings

  test "returns 404 for a non-admin user" do
    conn = build_conn() |> login_user(user_fixture()) |> get(~p"/admin/settings")

    assert response(conn, 404)
  end

  describe "default taxonomy" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows the config-derived value when no override is stored", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(lv, "h1", "Site Settings")
      assert has_element?(lv, "#default-taxonomy-source", "from the application config")
      assert has_element?(lv, "#default-taxonomy-source strong", "ebird/v2025")
      refute has_element?(lv, "#reset-taxonomy")
    end

    test "lists imported books as options", %{conn: conn} do
      Ornitho.Factory.insert(:book, slug: "ebird", version: "v2026")

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(lv, "#default-taxonomy-form option[value='ebird/v2026']")
    end

    test "saving a selection stores the override", %{conn: conn} do
      Ornitho.Factory.insert(:book, slug: "ebird", version: "v2026")

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      lv
      |> element("#default-taxonomy-form")
      |> render_submit(%{"default_taxonomy" => "ebird/v2026"})

      assert Settings.default_taxonomy() == "ebird/v2026"
      assert has_element?(lv, "#default-taxonomy-source", "Set here")
      assert has_element?(lv, "#reset-taxonomy")
    end

    test "submitting without a selection stores nothing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      lv
      |> element("#default-taxonomy-form")
      |> render_submit(%{"default_taxonomy" => ""})

      assert Settings.get_override(:default_taxonomy) == :error
      assert has_element?(lv, "#flash-group-error")
    end

    test "reset removes the override and returns to the config value", %{conn: conn} do
      {:ok, _} = Settings.put_setting(:default_taxonomy, "ebird/v2026")

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      lv |> element("#reset-taxonomy") |> render_click()

      assert Settings.get_override(:default_taxonomy) == :error
      assert Settings.default_taxonomy() == "ebird/v2025"
      assert has_element?(lv, "#default-taxonomy-source", "from the application config")
    end
  end
end
