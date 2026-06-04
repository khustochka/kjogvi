defmodule KjogviWeb.Live.My.Images.EditTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Images
  alias Kjogvi.ImagesFixtures

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
  end

  test "renders the form prefilled with the image's values", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user, title: "Old Title")

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

    assert has_element?(live, "h1", "Edit Image")
    assert has_element?(live, "#image-form input[name='image[title]'][value='Old Title']")
  end

  test "saves metadata changes and navigates to the image", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user, title: "Old Title")

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

    render_submit(live, "save", %{
      "image" => %{"slug" => image.slug, "title" => "New Title", "sort_order" => "5"}
    })

    assert_redirect(live, ~p"/my/images/#{image.id}")

    updated = Images.get_image!(user, image.id)
    assert updated.title == "New Title"
    assert updated.sort_order == 5
  end

  test "shows validation errors for an invalid slug", %{conn: conn, user: user} do
    image = ImagesFixtures.image_fixture(user: user)

    {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

    html = render_change(live, "validate", %{"image" => %{"slug" => ""}})

    assert html =~ "can&#39;t be blank"
  end

  test "raises for another user's image", %{conn: conn} do
    image = ImagesFixtures.image_fixture(user: user_fixture())

    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/my/images/#{image.id}/edit")
    end
  end
end
