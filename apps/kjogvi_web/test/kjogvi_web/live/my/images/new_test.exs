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
    upload_name = "#{slug}.jpg"

    upload =
      file_input(live, "#image-form", :image, [
        %{
          name: upload_name,
          content: File.read!(@sample_image),
          type: "image/jpeg"
        }
      ])

    assert render_upload(upload, upload_name) =~ "Replace image"

    # In test, waffle stores under a throwaway tmp prefix (see config/test.exs).
    # Stored files live outside the DB sandbox, so clean up the user's whole
    # token folder directly (the context's Repo connection is gone by on_exit).
    user_dir = Path.join([waffle_prefix(), "uploads/images", user.public_token])
    on_exit(fn -> File.rm_rf!(user_dir) end)

    render_submit(live, "save", %{"image" => %{"slug" => slug, "title" => "Sample Bird"}})

    image = Images.get_image_by_slug(slug)

    assert_redirect(live, ~p"/my/images/#{image.id}")

    assert image.title == "Sample Bird"
    assert image.user_id == user.id
    # Dimensions and EXIF date were extracted from the real file.
    assert image.extras["width"] == 60
    assert image.extras["height"] == 40
    assert image.extras["exif_date"] == "2021-07-15 09:30:00"

    # Files are stored under <user_token>/<image_token>, named after the
    # uploaded basename (here the slug). The original keeps its name with no
    # version suffix; variants are suffixed `_<version>`.
    storage_dir = Path.join(user_dir, image.token)

    assert File.exists?(Path.join(storage_dir, "#{slug}.jpg")),
           "expected stored original at #{Path.join(storage_dir, "#{slug}.jpg")}"

    for version <- ~w(thumbnail small medium large) do
      path = Path.join(storage_dir, "#{slug}_#{version}.jpg")
      assert File.exists?(path), "expected stored variant #{version} at #{path}"
    end
  end

  test "attaches a searched observation to the new image on save", %{conn: conn, user: user} do
    book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

    Ornitho.Factory.insert(:taxon,
      book: book,
      code: "gretit1",
      name_en: "Great Tit",
      name_sci: "Parus major"
    )

    {:ok, user} =
      Kjogvi.Users.update_user_settings(user, %{"default_book_signature" => "ebird/v2024"})

    # The sample image's EXIF capture date (2021-07-15) prefills the picker's
    # date, which scopes the search — so the matching observation must be on a
    # card of that day to surface in the dropdown.
    card =
      Kjogvi.Factory.insert(:card,
        user: user,
        location: Kjogvi.Factory.insert(:location),
        observ_date: ~D[2021-07-15]
      )

    obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "/ebird/v2024/gretit1")

    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    slug = "sample-bird-#{System.unique_integer([:positive])}"
    upload_name = "#{slug}.jpg"

    upload =
      file_input(live, "#image-form", :image, [
        %{name: upload_name, content: File.read!(@sample_image), type: "image/jpeg"}
      ])

    render_upload(upload, upload_name)

    user_dir = Path.join([waffle_prefix(), "uploads/images", user.public_token])
    on_exit(fn -> File.rm_rf!(user_dir) end)

    live |> element("#image-observations-search") |> render_keyup(%{"value" => "great tit"})

    live
    |> element("#image-observations-result-#{obs.id} button[phx-click=add_observation]")
    |> render_click()

    render_submit(live, "save", %{"image" => %{"slug" => slug}})

    image = Images.get_image_by_slug(slug) |> Kjogvi.Repo.preload(:observations)
    assert_redirect(live, ~p"/my/images/#{image.id}")
    assert Enum.map(image.observations, & &1.id) == [obs.id]
  end

  test "renders the client-side preview img after upload (entry consumed early)", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    upload =
      file_input(live, "#image-form", :image, [
        %{name: "preview.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
      ])

    render_upload(upload, "preview.jpg")

    # The hook fills this <img>'s src from the browser-held File; in the test we
    # can only assert the element (and its hook) are present, not the blob src.
    assert has_element?(live, "#upload-drop-zone[phx-hook=ImageUploadPreview]")
    assert has_element?(live, "#upload-drop-zone img[data-role=client-preview]")
  end

  test "prefills the observation date from the uploaded file's EXIF date", %{conn: conn} do
    {:ok, live, _html} = live(conn, ~p"/my/images/new")

    upload =
      file_input(live, "#image-form", :image, [
        %{name: "exif.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
      ])

    render_upload(upload, "exif.jpg")

    # The sample carries DateTimeOriginal 2021-07-15 (see the metadata test).
    assert has_element?(live, "#image-observations-date[value='2021-07-15']")
  end

  defp waffle_prefix do
    Application.get_env(:waffle, :storage_dir_prefix, "")
  end
end
