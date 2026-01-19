defmodule KjogviWeb.Live.My.Cards.FormTest do
  use KjogviWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Kjogvi.UsersFixtures

  describe "card form" do
    setup do
      user = UsersFixtures.user_fixture()
      token = Kjogvi.Users.generate_user_session_token(user)

      conn =
        build_conn()
        |> Phoenix.ConnTest.init_test_session(%{})
        |> Plug.Conn.put_session(:user_token, token)

      {:ok, conn: conn, user: user}
    end

    test "renders new card form", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "New Card"
      assert html =~ "Observation Date"
      assert html =~ "Effort Type"
    end

    test "renders effort type as dropdown", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "select"
      assert html =~ "Stationary"
      assert html =~ "Traveling"
    end

    test "renders location field with type=search", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "Location"
      assert html =~ "type=\"search\""
    end

    test "renders observation section with add button", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "Observations"
      assert html =~ "Add Observation"
    end

    test "can add observations", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "Taxon Key"
      assert html =~ "Quantity"
    end

    test "can remove observations", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "Remove"

      lv |> element("button", "Remove") |> render_click()

      html = render(lv)
      assert html =~ "No observations yet"
    end

    test "renders form fields in 3-column layout", %{conn: conn, user: _user} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")
      assert html =~ "sm:grid-cols-3"
    end

    test "taxon input has type=search", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      html = render(lv)
      assert html =~ "type=\"search\""
      assert html =~ "Taxon Key"
    end

    test "closing location search on blur", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> render_click("close_location_search")

      html = render(lv)
      refute html =~ "test"
    end

    test "closing taxon search on blur", %{conn: conn, user: _user} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      lv |> element("button", "Add Observation") |> render_click()

      lv |> render_click("close_taxon_search")

      html = render(lv)
      refute html =~ "great"
    end
  end
end
