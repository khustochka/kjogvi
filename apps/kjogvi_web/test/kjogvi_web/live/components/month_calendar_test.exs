defmodule KjogviWeb.Live.Components.MonthCalendarTest do
  use KjogviWeb.ConnCase
  import Phoenix.LiveViewTest

  alias Kjogvi.UsersFixtures
  alias KjogviWeb.Live.Components.MonthCalendar

  defp conn_for_user(user) do
    token = Kjogvi.Users.generate_user_session_token(user)

    build_conn()
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  describe "calendar_weeks/2" do
    test "generates correct grid for a known month" do
      # June 2024 starts on Saturday (day_of_week = 6)
      weeks = MonthCalendar.calendar_weeks(2024, 6)

      # First week should have 5 empty + Sat(1) Sun(2)
      first_week = hd(weeks)
      assert Enum.take(first_week, 5) == [:empty, :empty, :empty, :empty, :empty]
      assert Enum.at(first_week, 5) == {:day, 1}
      assert Enum.at(first_week, 6) == {:day, 2}

      # Should have 5 weeks for June 2024
      assert length(weeks) == 5

      # Last day (30) should be in last week
      last_week = List.last(weeks)
      assert {:day, 30} in last_week
    end

    test "generates correct grid for month starting on Monday" do
      # July 2024 starts on Monday (day_of_week = 1)
      weeks = MonthCalendar.calendar_weeks(2024, 7)

      first_week = hd(weeks)
      assert hd(first_week) == {:day, 1}
    end
  end

  describe "calendar rendering on card form" do
    setup do
      user = UsersFixtures.user_fixture()
      conn = conn_for_user(user)
      {:ok, conn: conn, user: user}
    end

    test "renders month name and weekday headers", %{conn: conn} do
      {:ok, _lv, html} = live(conn, "/my/cards/new")

      assert html =~ "Observation Date"
      # Should have weekday headers
      assert html =~ "Mo"
      assert html =~ "Tu"
      assert html =~ "We"
      assert html =~ "Th"
      assert html =~ "Fr"
      assert html =~ "Sa"
      assert html =~ "Su"
    end

    test "renders day buttons", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Day 15 should exist as a button in any month
      assert has_element?(lv, "#day-15")
    end

    test "renders hidden input for form submission", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      assert has_element?(lv, "#observ_date_calendar-hidden")
    end

    test "clicking a day sends date to parent", %{conn: conn} do
      {:ok, lv, _html} = live(conn, "/my/cards/new")

      # Click day 10
      lv |> element("#day-10") |> render_click()

      # The hidden input should now have a date value
      html = render(lv)
      assert html =~ ~r/value="\d{4}-\d{2}-10"/
    end

    test "prev/next month navigation changes displayed month", %{conn: conn} do
      {:ok, lv, html} = live(conn, "/my/cards/new")

      # Get the current month label
      current_month_label = extract_month_label(html)

      # Navigate to previous month
      lv |> element("button[phx-click=prev_month]") |> render_click()
      html = render(lv)
      prev_month_label = extract_month_label(html)

      refute current_month_label == prev_month_label

      # Navigate forward twice to go past original
      lv |> element("button[phx-click=next_month]") |> render_click()
      lv |> element("button[phx-click=next_month]") |> render_click()
      html = render(lv)
      next_month_label = extract_month_label(html)

      refute current_month_label == next_month_label
    end

    test "highlights days with existing cards", %{conn: conn, user: user} do
      insert(:card, user: user, observ_date: Date.utc_today())

      {:ok, lv, _html} = live(conn, "/my/cards/new")

      today = Date.utc_today()
      day_button = element(lv, "#day-#{today.day}")
      html = render(day_button)

      assert html =~ "bg-teal-100"
    end
  end

  defp extract_month_label(html) do
    case Regex.run(~r/id="observ_date_calendar-month-label"[^>]*>\s*([^<]+)/, html) do
      [_, label] -> String.trim(label)
      _ -> nil
    end
  end
end
