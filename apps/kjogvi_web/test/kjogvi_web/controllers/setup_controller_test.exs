defmodule KjogviWeb.SetupControllerTest do
  use KjogviWeb.ConnCase

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
