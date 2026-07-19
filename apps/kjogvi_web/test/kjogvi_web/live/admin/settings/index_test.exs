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

  describe "access flags" do
    setup %{conn: conn} do
      %{conn: login_user(conn, admin_fixture())}
    end

    test "shows each feature as enabled when no override is stored", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      for key <-
            ~w(registration_disabled forgot_reset_password_disabled email_confirmation_disabled) do
        assert has_element?(lv, "#flag-#{key}-state", "enabled")
        assert has_element?(lv, "#toggle-#{key}", "Disable")
      end
    end

    test "clicking Disable disables the feature", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(lv, "#toggle-registration_disabled", "Disable registration")
      lv |> element("#toggle-registration_disabled") |> render_click()

      assert Settings.registration_disabled?()
      assert has_element?(lv, "#flag-registration_disabled-state", "Registration disabled")
      assert has_element?(lv, "#toggle-registration_disabled", "Enable registration")
    end

    test "clicking Enable re-enables the feature", %{conn: conn} do
      {:ok, _} = Settings.put_setting(:registration_disabled, true)

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(lv, "#toggle-registration_disabled", "Enable registration")
      lv |> element("#toggle-registration_disabled") |> render_click()

      refute Settings.registration_disabled?()
      assert has_element?(lv, "#flag-registration_disabled-state", "Registration enabled")
    end

    test "the button stores what its label says, from a stored-false row", %{conn: conn} do
      # A row already holding `false` renders the same as no row at all, so this
      # is the state where an inverted phx-value silently no-ops.
      {:ok, _} = Settings.put_setting(:registration_disabled, false)

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(lv, "#toggle-registration_disabled", "Disable registration")
      lv |> element("#toggle-registration_disabled") |> render_click()

      assert Settings.get_override(:registration_disabled) == {:ok, true}
    end

    test "toggling one flag leaves the others alone", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      lv |> element("#toggle-email_confirmation_disabled") |> render_click()

      assert Settings.email_confirmation_disabled?()
      refute Settings.registration_disabled?()
      assert Settings.get_override(:forgot_reset_password_disabled) == :error
    end

    test "re-enabling stores false rather than removing the row", %{conn: conn} do
      {:ok, _} = Settings.put_setting(:registration_disabled, true)

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      lv |> element("#toggle-registration_disabled") |> render_click()

      refute Settings.registration_disabled?()
      assert Settings.get_override(:registration_disabled) == {:ok, false}
    end

    test "a stored flag renders as disabled without a reset control", %{conn: conn} do
      {:ok, _} = Settings.put_setting(:forgot_reset_password_disabled, true)

      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      assert has_element?(
               lv,
               "#flag-forgot_reset_password_disabled-state",
               "Password reset disabled"
             )

      refute has_element?(lv, "#reset-forgot_reset_password_disabled")
    end

    test "an unknown flag key is rejected", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/admin/settings")

      Process.flag(:trap_exit, true)

      catch_exit(
        render_click(lv, "save_flag", %{"key" => "admin_disabled", "disabled" => "true"})
      )

      assert Settings.get_override(:admin_disabled) == :error
    end
  end
end
