defmodule KjogviWeb.Live.My.Account.SettingsLogbookTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Kjogvi.UsersFixtures
  alias Kjogvi.Repo

  describe "logbook settings" do
    test "settings page renders logbook settings section", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, _lv, html} = live(conn, ~p"/my/account/settings")

      assert html =~ "Logbook settings"
      assert html =~ "World"
      assert html =~ "Life"
      assert html =~ "Year"
    end

    test "saving logbook settings persists them", %{conn: conn} do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      post(conn, "/my/account/settings", %{
        "user" => %{
          "extras" => %{
            "logbook_settings" => %{
              "0" => %{"location_id" => "", "life" => "true", "year" => "false"}
            }
          }
        }
      })

      user = Repo.get!(Kjogvi.Users.User, user.id)
      assert length(user.extras.logbook_settings) == 1

      setting = hd(user.extras.logbook_settings)
      assert setting.location_id == nil
      assert setting.life == true
      assert setting.year == false
    end
  end
end
