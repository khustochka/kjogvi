defmodule KjogviWeb.Live.My.Settings.PreferencesTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.Repo

  describe "Preferences page" do
    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings/preferences")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/account/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "default taxonomy" do
    test "user can select default book and it is saved", %{conn: conn} do
      book = Ornitho.Factory.insert(:book)

      user = user_fixture()

      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "default_book_signature" => "#{book.slug}/#{book.version}"
        }
      })
      |> render_submit()

      user = Repo.get!(Kjogvi.Accounts.User, user.id)
      assert user.default_book_signature == "#{book.slug}/#{book.version}"
    end
  end

  describe "logbook settings" do
    test "preferences page renders logbook settings section", %{conn: conn} do
      user = user_fixture()

      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      assert html =~ "Logbook settings"
      assert html =~ "World"
      assert html =~ "Life"
      assert html =~ "Year"
    end

    test "saving logbook settings persists them", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/settings/preferences")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "extras" => %{
            "logbook_settings" => %{
              "0" => %{"location_id" => "", "life" => "true", "year" => "false"}
            }
          }
        }
      })
      |> render_submit()

      user = Repo.get!(Kjogvi.Accounts.User, user.id)
      assert length(user.extras.logbook_settings) == 1

      setting = hd(user.extras.logbook_settings)
      assert setting.location_id == nil
      assert setting.life == true
      assert setting.year == false
    end
  end
end
