defmodule KjogviWeb.Live.My.Images.ShowTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Images
  alias Kjogvi.ImagesFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders the image details", %{conn: conn, user: user} do
    image =
      ImagesFixtures.image_fixture(
        user: user,
        title: "Sandhill Crane",
        extras: %{
          "width" => 1200,
          "height" => 800,
          "exif_date" => "2025-05-25 18:50:14",
          "content_type" => "image/jpeg",
          "legacy_title" => "Grus canadensis"
        }
      )

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}")

    assert has_element?(live, "h1", "Sandhill Crane")
    assert has_element?(live, "dd", "1200 × 800")
    assert has_element?(live, "dd", "May 25, 2025 18:50")
    assert has_element?(live, "dd", "image/jpeg")
    assert has_element?(live, "dd", "Grus canadensis")
    assert has_element?(live, "a", "Original")
  end

  test "links to an attached observation's card", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user)
    card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
    obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "sancra")
    {:ok, _} = Images.attach_observations(image, [obs.id])

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}")

    assert has_element?(live, "#observation-#{obs.id}")
    assert has_element?(live, "a[href='/my/cards/#{card.id}']")
  end

  test "deleting navigates back to the gallery", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user)

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}")

    render_click(live, "delete")
    assert_redirect(live, ~p"/my/images")
    assert Images.get_image_by_slug(image.slug) == nil
  end

  test "raises for another user's image", %{conn: conn} do
    image = ImagesFixtures.image_fixture(user: user_fixture())

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/my/images/#{image.id}")
    end
  end
end
