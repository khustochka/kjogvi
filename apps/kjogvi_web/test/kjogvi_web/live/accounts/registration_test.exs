defmodule KjogviWeb.Live.Accounts.RegistrationTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/account/register")

      assert html =~ "Register"
      assert html =~ "Log in"
      assert html =~ "Should be 12–72 characters."
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> login_user(user_fixture())
        |> live(~p"/account/register")
        |> follow_redirect(conn, "/")

      assert {:ok, _conn} = result
    end

    test "does not flag a malformed email while typing", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      # Live validation must not surface the email-format error on change.
      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces", "password" => "too short"})

      refute result =~ "Must have the @ sign and no spaces."
      # A too-short password reddens the hint instead of listing a separate error.
      assert has_element?(lv, "#registration_form_password_hint.text-rose-600")
    end

    test "flags a malformed email once the field is blurred", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      result =
        lv
        |> element("#registration_form_email")
        |> render_blur(value: "with spaces")

      assert result =~ "Must have the @ sign and no spaces."
    end

    test "flags a malformed email on submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => "with spaces", "password" => "too short"}
        )
        |> render_submit()

      assert result =~ "Must have the @ sign and no spaces."
    end

    test "flags an already-taken email once the field is blurred", %{conn: conn} do
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/account/register")

      result =
        lv
        |> element("#registration_form_email")
        |> render_blur(value: user.email)

      assert result =~ "has already been taken"
    end
  end

  describe "register user" do
    test "creates account and logs the user in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      email = unique_user_email()

      form =
        form(lv, "#registration_form",
          user: %{"email" => email, "password" => valid_user_password()}
        )

      render_submit(form)
      conn = follow_trigger_action(form, conn)

      assert redirected_to(conn) == ~p"/"

      # Now do a logged in request and assert on the menu
      conn = get(conn, "/")
      response = html_response(conn, 200)
      assert response =~ email
      assert response =~ "Log out"
    end

    test "derives the nickname from the email when none is entered", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      email = "john.doe#{System.unique_integer([:positive])}@example.com"

      form =
        form(lv, "#registration_form",
          user: %{"email" => email, "password" => valid_user_password()}
        )

      render_submit(form)
      follow_trigger_action(form, conn)

      user = Kjogvi.Accounts.get_user_by_email(email)
      assert user.nickname =~ ~r/^john_doe/
    end

    test "renders inline error for duplicated email on submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      user = user_fixture()

      result =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => valid_user_password()}
        )
        |> render_submit()

      assert result =~ "has already been taken"
    end

    test "reddens the password hint for a too-short password on submit", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      lv
      |> form("#registration_form",
        user: %{"email" => unique_user_email(), "password" => "short"}
      )
      |> render_submit()

      assert has_element?(lv, "#registration_form_password_hint.text-rose-600")
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/account/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/account/login")

      assert login_html =~ "Log in"
    end
  end
end
