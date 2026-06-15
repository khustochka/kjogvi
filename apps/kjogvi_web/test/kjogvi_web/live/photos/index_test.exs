defmodule KjogviWeb.Live.Photos.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.ImagesFixtures

  test "renders the heading", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/community/photos")

    assert has_element?(live, "h1", "Photos")
  end

  test "shows an empty state when there are no images", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/community/photos")

    assert has_element?(live, "#photos-empty")
  end

  test "lists images from all users", %{conn: conn} do
    image_one = ImagesFixtures.image_fixture(user: user_fixture(), title: "Sandhill Crane")
    image_two = ImagesFixtures.image_fixture(user: user_fixture(), title: "Tundra Swan")

    {:ok, live, _html} = live(conn, ~p"/community/photos")

    refute has_element?(live, "#photos-empty")
    assert has_element?(live, "#photos-#{image_one.id}")
    assert has_element?(live, "#photos-#{image_two.id}")
  end

  test "orders images newest first", %{conn: conn} do
    older = ImagesFixtures.image_fixture(user: user_fixture())
    newer = ImagesFixtures.image_fixture(user: user_fixture())

    {:ok, _live, html} = live(conn, ~p"/community/photos")

    [first, second] =
      Regex.scan(~r/id="photos-(\d+)"/, html, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)

    assert first == newer.id
    assert second == older.id
  end

  test "renders pagination links when there is more than one page", %{conn: conn} do
    user = user_fixture()
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, _live, html} = live(conn, ~p"/community/photos")

    assert html =~ "/community/photos/page/2"
  end

  test "shows a later page at its own route", %{conn: conn} do
    user = user_fixture()
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, live, _html} = live(conn, ~p"/community/photos/page/2")

    # 25 images at 24 per page leaves exactly one on page 2.
    assert length(Regex.scan(~r/id="photos-\d+"/, render(live))) == 1
  end
end
