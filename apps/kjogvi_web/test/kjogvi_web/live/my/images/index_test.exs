defmodule KjogviWeb.Live.My.Images.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.ImagesFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders the heading and add button", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images")

    assert has_element?(live, "h1", "Images")
    assert has_element?(live, "a[href='/my/images/new']")
  end

  test "shows an empty state when there are no images", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images")

    assert has_element?(live, "#images-empty")
  end

  test "lists the user's images", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user, title: "Sandhill Crane")

    {:ok, live, _html} = live(conn, ~p"/my/images")

    refute has_element?(live, "#images-empty")
    assert has_element?(live, "#images-#{image.id}")
    assert has_element?(live, "a[href='/my/images/#{image.id}']")
  end

  test "does not list another user's images", %{conn: conn} do
    other_image = ImagesFixtures.image_fixture(user: user_fixture())

    {:ok, live, _html} = live(conn, ~p"/my/images")

    refute has_element?(live, "#images-#{other_image.id}")
  end
end
