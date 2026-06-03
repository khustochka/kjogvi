defmodule KjogviWeb.Live.My.Images.NewTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  setup %{conn: conn} do
    %{conn: log_in_user(conn, user_fixture())}
  end

  test "renders the upload drop zone", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    assert has_element?(live, "h1", "Add Image")
    assert has_element?(live, "#upload-drop-zone")
  end

  test "hides the metadata form until a file is uploaded", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    refute has_element?(live, "#image-form input[name='image[slug]']")
  end

  test "rejects a non-image file", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    upload =
      file_input(live, "#image-form", :image, [
        %{name: "notes.txt", content: "not an image", type: "text/plain"}
      ])

    render_upload(upload, "notes.txt")

    assert has_element?(live, "#upload-drop-zone", "File type not accepted")
  end

  test "save without a file flashes an error", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    html = render_submit(live, "save", %{"image" => %{"slug" => "x"}})

    assert html =~ "Please choose a file to upload"
  end
end
