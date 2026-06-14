defmodule KjogviWeb.Live.My.Account.SettingsTest do
  use KjogviWeb.ConnCase, async: true

  alias Kjogvi.Accounts
  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  describe "Settings page" do
    test "renders settings page", %{conn: conn} do
      {:ok, _lv, html} =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/my/account/settings")

      assert html =~ "Change Email"
      assert html =~ "Change Password"
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/account/settings")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "update user settings form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: log_in_user(conn, user), user: user}
    end

    test "renders the nickname field prefilled with the current nickname", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      assert lv
             |> element("#user_nickname")
             |> render() =~ ~s(value="#{user.nickname}")
    end

    test "updates the nickname", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "newnick"}})
        |> render_submit()

      assert result =~ "User account updated."
      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).nickname == "newnick"
    end

    test "shows an error and does not save an invalid nickname", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "bad nick!"}})
        |> render_submit()

      assert result =~ "must contain only letters, digits, hyphens and underscores"
      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).nickname == user.nickname
    end

    test "shows nickname errors on change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "ab"}})
        |> render_change()

      assert result =~ "should be at least 3 character(s)"
    end

    test "renders hints for the nickname and display name fields", %{conn: conn, user: user} do
      {:ok, _lv, html} = conn |> log_in_user(user) |> live(~p"/my/account/settings")

      assert html =~ "lowercase letters, digits, hyphens and underscores"
      assert html =~ "letters, spaces and common punctuation"
    end

    test "marks the required nickname field with an asterisk", %{conn: conn, user: user} do
      {:ok, lv, _html} = conn |> log_in_user(user) |> live(~p"/my/account/settings")

      assert lv |> element("label[for=user_nickname]") |> render() =~ "*"
    end

    test "renders the display name field prefilled with the current display name", %{conn: conn} do
      user = user_fixture(%{display_name: "Jane Doe"})

      {:ok, lv, _html} =
        conn |> log_in_user(user) |> live(~p"/my/account/settings")

      assert lv
             |> element("#user_display_name")
             |> render() =~ ~s(value="Jane Doe")
    end

    test "updates the display name", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      lv
      |> form("#settings_form", %{
        "user" => %{"nickname" => user.nickname, "display_name" => "Jane Doe"}
      })
      |> render_submit()

      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).display_name == "Jane Doe"
    end

    test "shows an error and does not save an invalid display name", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{"nickname" => user.nickname, "display_name" => "no_underscores"}
        })
        |> render_submit()

      assert result =~ "must contain only letters, spaces and common punctuation"
      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).display_name == user.display_name
    end
  end

  describe "update email form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user email", %{conn: conn, password: password, user: user} do
      new_email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => password,
          "user" => %{"email" => new_email}
        })
        |> render_submit()

      assert result =~ "A link to confirm your email"
      assert Accounts.get_user_by_email(user.email)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> element("#email_form")
        |> render_change(%{
          "action" => "update_email",
          "current_password" => "invalid",
          "user" => %{"email" => "with spaces"}
        })

      assert result =~ "Change Email"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#email_form", %{
          "current_password" => "invalid",
          "user" => %{"email" => user.email}
        })
        |> render_submit()

      assert result =~ "Change Email"
      assert result =~ "did not change"
      assert result =~ "is not valid"
    end
  end

  describe "update password form" do
    setup %{conn: conn} do
      password = valid_user_password()
      user = user_fixture(%{password: password})
      %{conn: log_in_user(conn, user), user: user, password: password}
    end

    test "updates the user password", %{conn: conn, user: user, password: password} do
      new_password = valid_user_password()

      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      form =
        form(lv, "#password_form", %{
          "current_password" => password,
          "user" => %{
            "email" => user.email,
            "password" => new_password,
            "password_confirmation" => new_password
          }
        })

      render_submit(form)

      new_password_conn = follow_trigger_action(form, conn)

      assert redirected_to(new_password_conn) == ~p"/my/account/settings"

      assert get_session(new_password_conn, :user_token) != get_session(conn, :user_token)

      assert Phoenix.Flash.get(new_password_conn.assigns.flash, :info) =~
               "Password updated successfully"

      assert Accounts.get_user_by_email_and_password(user.email, new_password)
    end

    test "renders errors with invalid data (phx-change)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> element("#password_form")
        |> render_change(%{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
    end

    test "renders errors with invalid data (phx-submit)", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/account/settings")

      result =
        lv
        |> form("#password_form", %{
          "current_password" => "invalid",
          "user" => %{
            "password" => "too short",
            "password_confirmation" => "does not match"
          }
        })
        |> render_submit()

      assert result =~ "Change Password"
      assert result =~ "should be at least 12 character(s)"
      assert result =~ "does not match password"
      assert result =~ "is not valid"
    end
  end

  describe "confirm email" do
    setup %{conn: conn} do
      user = user_fixture()
      email = unique_user_email()

      token =
        extract_user_token(fn url ->
          Accounts.deliver_user_update_email_instructions(%{user | email: email}, user.email, url)
        end)

      %{conn: log_in_user(conn, user), token: token, email: email, user: user}
    end

    test "updates the user email once", %{conn: conn, user: user, token: token, email: email} do
      {:error, redirect} = live(conn, ~p"/my/account/settings/confirm_email/#{token}")

      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/account/settings"
      assert %{"info" => message} = flash
      assert message == "Email changed successfully."
      refute Accounts.get_user_by_email(user.email)
      assert Accounts.get_user_by_email(email)

      # use confirm token again
      {:error, redirect} = live(conn, ~p"/my/account/settings/confirm_email/#{token}")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/account/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
    end

    test "does not update email with invalid token", %{conn: conn, user: user} do
      {:error, redirect} = live(conn, ~p"/my/account/settings/confirm_email/oops")
      assert {:live_redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/my/account/settings"
      assert %{"error" => message} = flash
      assert message == "Email change link is invalid or it has expired."
      assert Accounts.get_user_by_email(user.email)
    end

    test "redirects if user is not logged in", %{token: token} do
      conn = build_conn()
      {:error, redirect} = live(conn, ~p"/my/account/settings/confirm_email/#{token}")
      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/users/log_in"
      assert %{"error" => message} = flash
      assert message == "You must log in to access this page."
    end
  end
end
