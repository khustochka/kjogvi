defmodule KjogviWeb.Live.My.Images.IndexTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

  alias Kjogvi.ImagesFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: login_user(conn, user), user: user}
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

  test "orders images newest first", %{conn: conn, user: user} do
    older = ImagesFixtures.image_fixture(user: user)
    newer = ImagesFixtures.image_fixture(user: user)

    {:ok, _live, html} = live(conn, ~p"/my/images")

    [first, second] =
      Regex.scan(~r/id="images-(\d+)"/, html, capture: :all_but_first)
      |> List.flatten()
      |> Enum.map(&String.to_integer/1)

    assert first == newer.id
    assert second == older.id
  end

  test "renders pagination links when there is more than one page", %{conn: conn, user: user} do
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, _live, html} = live(conn, ~p"/my/images")

    assert html =~ "/my/images/page/2"
  end

  test "shows a later page at its own route", %{conn: conn, user: user} do
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, live, _html} = live(conn, ~p"/my/images/page/2")

    # 25 images at 24 per page leaves exactly one on page 2.
    assert live |> element("#images-grid-p2") |> render() =~ "images-"
    assert length(Regex.scan(~r/id="images-\d+"/, render(live))) == 1
  end

  # Each thumbnail is keyed by image id. Without it the per-image <.link> wrapper
  # survives the patch and the old <img> is reused with a new src, leaving the
  # previous photo on screen under the new caption.
  test "thumbnails are keyed per image so none are reused across pages", %{conn: conn, user: user} do
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, _live, page1} = live(conn, ~p"/my/images")
    {:ok, _live, page2} = live(conn, ~p"/my/images/page/2")

    thumb_ids = fn html ->
      ~r/id="image-thumb-(\d+)"/ |> Regex.scan(html) |> Enum.map(&Enum.at(&1, 1)) |> MapSet.new()
    end

    assert MapSet.disjoint?(thumb_ids.(page1), thumb_ids.(page2))
  end

  # The grid id carries the page so a page change swaps the whole block instead
  # of patching stale thumbnails under new captions.
  test "the grid id changes with the page", %{conn: conn, user: user} do
    for _ <- 1..25, do: ImagesFixtures.image_fixture(user: user)

    {:ok, live, _html} = live(conn, ~p"/my/images")
    assert has_element?(live, "#images-grid-p1")

    {:ok, live, _html} = live(conn, ~p"/my/images/page/2")
    assert has_element?(live, "#images-grid-p2")
    refute has_element?(live, "#images-grid-p1")
  end
end
