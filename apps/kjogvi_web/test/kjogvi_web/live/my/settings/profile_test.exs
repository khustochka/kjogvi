defmodule KjogviWeb.Live.My.Settings.ProfileTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures
  import Kjogvi.GeoFixtures

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.UserProfile
  alias Kjogvi.Repo

  describe "Profile page" do
    test "renders profile page", %{conn: conn} do
      {:ok, lv, _html} =
        conn
        |> login_user(user_fixture())
        |> live(~p"/my/settings/profile")

      assert lv |> element("#settings_form") |> has_element?()
    end

    test "redirects if user is not logged in", %{conn: conn} do
      assert {:error, redirect} = live(conn, ~p"/my/settings/profile")

      assert {:redirect, %{to: path, flash: flash}} = redirect
      assert path == ~p"/account/login"
      assert %{"error" => "You must log in to access this page."} = flash
    end
  end

  describe "bare settings URL" do
    test "redirects /my/settings to /my/settings/profile", %{conn: conn} do
      conn = login_user(conn, user_fixture())

      assert {:error, {:live_redirect, %{to: path}}} = live(conn, ~p"/my/settings")
      assert path == ~p"/my/settings/profile"
    end
  end

  describe "update profile form" do
    setup %{conn: conn} do
      user = user_fixture()
      %{conn: login_user(conn, user), user: user}
    end

    test "renders the nickname field prefilled with the current nickname", %{
      conn: conn,
      user: user
    } do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      assert lv
             |> element("#user_nickname")
             |> render() =~ ~s(value="#{user.nickname}")
    end

    test "updates the nickname", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "newnick"}})
        |> render_submit()

      assert result =~ "User account updated."
      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).nickname == "newnick"
    end

    test "shows an error and does not save an invalid nickname", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "bad nick!"}})
        |> render_submit()

      assert result =~ "must contain only letters, digits, hyphens and underscores"
      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).nickname == user.nickname
    end

    test "shows nickname errors on change", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      result =
        lv
        |> form("#settings_form", %{"user" => %{"nickname" => "ab"}})
        |> render_change()

      assert result =~ "should be at least 3 character(s)"
    end

    test "renders hints for the nickname and display name fields", %{conn: conn, user: user} do
      {:ok, _lv, html} = conn |> login_user(user) |> live(~p"/my/settings/profile")

      assert html =~ "lowercase letters, digits, hyphens and underscores"
      assert html =~ "letters, spaces and common punctuation"
    end

    test "marks the required nickname field with an asterisk", %{conn: conn, user: user} do
      {:ok, lv, _html} = conn |> login_user(user) |> live(~p"/my/settings/profile")

      assert lv |> element("label[for=user_nickname]") |> render() =~ "*"
    end

    test "renders the display name field prefilled with the current display name", %{conn: conn} do
      user = user_fixture(%{display_name: "Jane Doe"})

      {:ok, lv, _html} =
        conn |> login_user(user) |> live(~p"/my/settings/profile")

      assert lv
             |> element("#user_display_name")
             |> render() =~ ~s(value="Jane Doe")
    end

    test "updates the display name", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      lv
      |> form("#settings_form", %{
        "user" => %{"nickname" => user.nickname, "display_name" => "Jane Doe"}
      })
      |> render_submit()

      assert Kjogvi.Repo.get!(Kjogvi.Accounts.User, user.id).display_name == "Jane Doe"
    end

    test "shows an error and does not save an invalid display name", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

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

  describe "profile fields" do
    setup %{conn: conn} do
      user = user_fixture()
      location_fixture(%{location_type: :country, iso_code: "US", name_en: "United States"})
      %{conn: login_user(conn, user), user: user}
    end

    test "renders the profile fields", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      assert lv |> element("#user_profile_0_about") |> has_element?()
      assert lv |> element("#user_profile_0_country") |> has_element?()
      assert lv |> element("#user_profile_0_ebird_profile_url") |> has_element?()
      assert lv |> element("#user_profile_0_website_url") |> has_element?()
    end

    test "lists common countries in the country select", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      assert lv
             |> element("#user_profile_0_country option[value=US]")
             |> render() =~ "United States"
    end

    test "saves the profile fields", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      lv
      |> form("#settings_form", %{
        "user" => %{
          "nickname" => user.nickname,
          "profile" => %{
            "about" => "A keen birder.",
            "country" => "US",
            "ebird_profile_url" => "https://ebird.org/profile/abc",
            "website_url" => "https://example.com"
          }
        }
      })
      |> render_submit()

      profile = Repo.get_by(UserProfile, user_id: user.id)
      assert profile.about == "A keen birder."
      assert profile.country == "US"
      assert profile.ebird_profile_url == "https://ebird.org/profile/abc"
      assert profile.website_url == "https://example.com"
    end

    test "prefills saved profile fields", %{conn: conn, user: user} do
      {:ok, _} =
        Accounts.update_user_profile_settings(user, %{
          "profile" => %{"website_url" => "https://example.com"}
        })

      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      assert lv |> element("#user_profile_0_website_url") |> render() =~
               ~s(value="https://example.com")
    end

    test "shows a validation error for a bad URL and does not save", %{conn: conn, user: user} do
      {:ok, lv, _html} = live(conn, ~p"/my/settings/profile")

      result =
        lv
        |> form("#settings_form", %{
          "user" => %{
            "nickname" => user.nickname,
            "profile" => %{"website_url" => "not-a-url"}
          }
        })
        |> render_submit()

      assert result =~ "must be a valid http(s) URL"
      refute Repo.get_by(UserProfile, user_id: user.id)
    end
  end
end
