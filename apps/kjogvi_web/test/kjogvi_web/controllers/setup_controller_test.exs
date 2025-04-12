defmodule KjogviWeb.SetupControllerTest do
  use KjogviWeb.ConnCase, async: true

  describe "GET /setup" do
    @tag :no_main_user
    test "if there is no main user it redirects to /setup", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/setup"
    end

    test "if there is main user, setup paths are unavailable", %{conn: conn} do
      conn = get(conn, ~p"/setup")
      assert html_response(conn, 404)
    end
  end

  describe "POST /setup/register" do
    @tag :no_main_user
    test "returns to setup if setup code is not set in session", %{conn: conn} do
      conn =
        post(conn, ~p"/setup/register", %{
          "user" => %{"email" => "user@email.test", "password" => "1234567890ab"}
        })

      assert redirected_to(conn) == ~p"/setup"

      assert is_nil(Kjogvi.Settings.main_user())
    end

    @tag :no_main_user
    test "returms to setup if setup code is not provided", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:setup_code, "abc123")
        |> post(~p"/setup/register", %{
          "user" => %{"email" => "user@email.test", "password" => "1234567890ab"}
        })

      assert redirected_to(conn) == ~p"/setup"

      assert is_nil(Kjogvi.Settings.main_user())
    end

    @tag :no_main_user
    test "renders registration form if the correct setup code is provided", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:setup_code, "abc123")
        |> post(~p"/setup/register", %{
          "user" => %{
            "email" => "user@email.test",
            "password" => "1234567890ab"
          },
          "setup_code" => "abc123"
        })

      assert html_response(conn, 200)
    end
  end

  describe "POST /setup" do
    @tag :no_main_user
    test "cannot create admin if setup code is not set in session", %{conn: conn} do
      conn =
        post(conn, ~p"/setup", %{
          "user" => %{"email" => "user@email.test", "password" => "1234567890ab"}
        })

      assert redirected_to(conn) == ~p"/setup"

      assert is_nil(Kjogvi.Settings.main_user())
    end

    @tag :no_main_user
    test "cannot create admin if setup code is not provided", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:setup_code, "abc123")
        |> post(~p"/setup", %{
          "user" => %{"email" => "user@email.test", "password" => "1234567890ab"}
        })

      assert redirected_to(conn) == ~p"/setup"

      assert is_nil(Kjogvi.Settings.main_user())
    end

    @tag :no_main_user
    test "creates admin if the correct setup code is provided", %{conn: conn} do
      conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> put_session(:setup_code, "abc123")
        |> post(~p"/setup", %{
          "user" => %{
            "email" => "user@email.test",
            "password" => "1234567890ab"
          },
          "setup_code" => "abc123"
        })

      assert redirected_to(conn) == ~p"/users/log_in"

      assert not is_nil(Kjogvi.Settings.main_user())
    end
  end
end
