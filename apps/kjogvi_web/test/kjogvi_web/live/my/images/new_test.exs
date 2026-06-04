defmodule KjogviWeb.Live.My.Images.NewTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Images

  # A small genuine JPEG (60×40) carrying an EXIF DateTimeOriginal tag.
  @sample_image Path.expand(
                  Path.join([
                    __DIR__,
                    "..",
                    "..",
                    "..",
                    "..",
                    "support",
                    "fixtures",
                    "files",
                    "sample_bird.jpg"
                  ])
                )

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: log_in_user(conn, user), user: user}
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

  test "validate tolerates the upload-only change event", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    # The file input fires phx-change before the metadata fields exist, so the
    # params carry only "_target" with no "image" key.
    assert render_change(live, "validate", %{"_target" => ["image"]})
  end

  test "save without a file flashes an error", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    html = render_submit(live, "save", %{"image" => %{"slug" => "x"}})

    assert html =~ "Please choose a file to upload"
  end

  test "uploads a real image, processes it, and stores metadata", %{conn: conn, user: user} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    slug = "sample-bird-#{System.unique_integer([:positive])}"

    upload =
      file_input(live, "#image-form", :image, [
        %{
          name: "sample_bird.jpg",
          content: File.read!(@sample_image),
          type: "image/jpeg"
        }
      ])

    assert render_upload(upload, "sample_bird.jpg") =~ "Replace image"

    # Stored files live outside the DB sandbox, so clean them up directly
    # rather than via the context (whose Repo connection is gone by on_exit).
    on_exit(fn ->
      File.rm_rf!(Path.join("apps/kjogvi_web/priv/static/uploads/images", slug))
    end)

    render_submit(live, "save", %{"image" => %{"slug" => slug, "title" => "Sample Bird"}})

    image = Images.get_image_by_slug(slug)

    assert_redirect(live, ~p"/my/images/#{image.id}")

    assert image.title == "Sample Bird"
    assert image.user_id == user.id
    # Dimensions and EXIF date were extracted from the real file.
    assert image.extras["width"] == 60
    assert image.extras["height"] == 40
    assert image.extras["exif_date"] == "2021-07-15 09:30:00"

    # The original and every resized variant were written to local storage.
    for version <- ~w(original thumbnail small medium large) do
      path =
        Path.join([
          "apps/kjogvi_web/priv/static",
          "uploads/images/#{slug}",
          "sample_bird_#{version}.jpg"
        ])

      assert File.exists?(path), "expected stored variant #{version} at #{path}"
    end
  end
end
