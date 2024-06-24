defmodule KjogviWeb.HomeControllerTest do
  use KjogviWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Kjogvi"
  end
end
