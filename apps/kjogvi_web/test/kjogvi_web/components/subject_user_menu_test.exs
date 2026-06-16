defmodule KjogviWeb.SubjectUserMenuTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  test "shows the subject user's lifelist and photos links in the user area", %{conn: conn} do
    user = user_fixture(display_name: "Jane Birder")

    {:ok, live, _html} = live(conn, ~p"/users/#{user.nickname}")

    assert has_element?(live, "#subject-user-menu")

    assert has_element?(
             live,
             "#subject-user-menu a[href='/users/#{user.nickname}']",
             "Jane Birder"
           )

    assert has_element?(live, "#subject-user-menu a[href='/users/#{user.nickname}/lifelist']")
    assert has_element?(live, "#subject-user-menu a[href='/users/#{user.nickname}/photos']")
  end

  test "is absent in the community area", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/community/lifelist")

    refute has_element?(live, "#subject-user-menu")
  end
end
