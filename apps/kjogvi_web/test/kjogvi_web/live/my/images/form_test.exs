defmodule KjogviWeb.Live.My.Images.FormTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Images
  alias Kjogvi.ImagesFixtures

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

  describe "new" do
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

    test "the slug is derived from the file name", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      upload =
        file_input(live, "#image-form", :image, [
          %{name: "My Great Bird.JPG", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "My Great Bird.JPG")

      assert has_element?(live, "#image-form input[name='image[slug]'][value='my-great-bird']")
    end

    test "re-picking a file overrides the slug from the new file name", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      first =
        file_input(live, "#image-form", :image, [
          %{name: "first.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(first, "first.jpg")
      assert has_element?(live, "#image-form input[name='image[slug]'][value='first']")

      second =
        file_input(live, "#image-form", :image, [
          %{name: "second.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(second, "second.jpg")
      assert has_element?(live, "#image-form input[name='image[slug]'][value='second']")
    end
  end

  describe "edit" do
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

  describe "edit / replace file" do
    test "hides the replace form until the replace action is started", %{
      conn: conn,
      user: user
    } do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      assert has_element?(live, "#replace-file-button")
      refute has_element?(live, "#replace-file-form")

      render_click(live, "start_replace")

      assert has_element?(live, "#replace-file-form")
      refute has_element?(live, "#replace-file-button")
    end

    test "canceling returns to the replace button", %{conn: conn, user: user} do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")
      render_click(live, "cancel_replace")

      assert has_element?(live, "#replace-file-button")
      refute has_element?(live, "#replace-file-form")
    end

    test "the cancel button is styled red", %{conn: conn, user: user} do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      assert has_element?(live, "#replace-file-form button.text-red-700", "Cancel")
    end

    test "uploads a new file, stores it, and re-extracts metadata", %{conn: conn, user: user} do
      image = create_stored_image(user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "replacement.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      assert render_upload(upload, "replacement.jpg") =~ "Replace image"

      user_dir = Path.join([waffle_prefix(), "uploads/images", user.public_token])
      on_exit(fn -> File.rm_rf!(user_dir) end)

      render_submit(live, "replace", %{})

      assert_redirect(live, ~p"/my/images/#{image.id}")

      replaced = Images.get_image!(user, image.id)
      assert replaced.file.file_name == "replacement.jpg"
      assert replaced.extras["width"] == 60
      assert replaced.extras["height"] == 40

      storage_dir = Path.join([user_dir, replaced.token])
      assert File.exists?(Path.join(storage_dir, "replacement.jpg"))
      assert File.exists?(Path.join(storage_dir, "replacement_medium.jpg"))
    end

    test "replacing without a chosen file flashes an error", %{conn: conn, user: user} do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")
      html = render_submit(live, "replace", %{})

      assert html =~ "Please choose a file to upload"
    end

    test "shows a hint that the main save will also replace the staged file", %{
      conn: conn,
      user: user
    } do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      # No staged file yet: no hint.
      refute has_element?(live, "#save-replaces-file-hint")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "staged.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "staged.jpg")

      assert has_element?(live, "#save-replaces-file-hint")
    end

    test "the main save applies a staged replacement alongside metadata", %{
      conn: conn,
      user: user
    } do
      image = create_stored_image(user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "via-save.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "via-save.jpg")

      user_dir = Path.join([waffle_prefix(), "uploads/images", user.public_token])
      on_exit(fn -> File.rm_rf!(user_dir) end)

      # Submit the MAIN form (not the replace button) with a metadata change.
      render_submit(live, "save", %{
        "image" => %{"slug" => image.slug, "title" => "Saved Together", "sort_order" => "100"}
      })

      assert_redirect(live, ~p"/my/images/#{image.id}")

      updated = Images.get_image!(user, image.id)
      # Metadata change persisted.
      assert updated.title == "Saved Together"
      # And the staged file was replaced (re-extracted name + dimensions).
      assert updated.file.file_name == "via-save.jpg"
      assert updated.extras["width"] == 60
      assert updated.extras["height"] == 40

      storage_dir = Path.join([user_dir, updated.token])
      assert File.exists?(Path.join(storage_dir, "via-save.jpg"))
    end

    test "uploading a replacement does not change the slug", %{conn: conn, user: user} do
      image = ImagesFixtures.image_fixture(user: user, slug: "kept-slug")

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "a-different-name.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "a-different-name.jpg")

      # The slug field still holds the stored slug, not the uploaded file's name.
      assert has_element?(live, "#image-form input[name='image[slug]'][value='kept-slug']")
    end

    test "uploading a replacement seeds the obs date from EXIF when no observations exist", %{
      conn: conn,
      user: user
    } do
      image = ImagesFixtures.image_fixture(user: user)

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      render_click(live, "start_replace")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "with-exif.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "with-exif.jpg")

      # No observations attached, so the picker date takes the file's EXIF date.
      assert has_element?(live, "#image-observations-date[value='2021-07-15']")
    end
  end

  describe "edit / observations" do
    setup %{user: user} do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "gretit1",
        name_en: "Great Tit",
        name_sci: "Parus major"
      )

      {:ok, user} =
        Kjogvi.Users.update_user_settings(user, %{"default_book_signature" => "ebird/v2024"})

      location = Kjogvi.Factory.insert(:location)

      card =
        Kjogvi.Factory.insert(:card,
          user: user,
          location: location,
          effort_type: "TRAVEL",
          start_time: ~T[08:15:00],
          duration_minutes: 90,
          distance_kms: 3.5
        )

      obs =
        Kjogvi.Factory.insert(:observation, card: card, taxon_key: "/ebird/v2024/gretit1")

      %{user: user, card: card, obs: obs}
    end

    test "uploading a replacement does not override the date when observations exist", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # Seeded from the attached observation's card (factory default 2023-08-29),
      # which differs from the sample file's EXIF date (2021-07-15).
      assert has_element?(live, "#image-observations-date[value='2023-08-29']")

      render_click(live, "start_replace")

      upload =
        file_input(live, "#replace-file-form", :image, [
          %{name: "replacement.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "replacement.jpg")

      # Still the observation's date, not the uploaded file's EXIF date.
      assert has_element?(live, "#image-observations-date[value='2023-08-29']")
    end

    test "renders the already-attached observations as tiles", %{
      conn: conn,
      user: user,
      card: card,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      tile = element(live, "#image-observations-selected-#{obs.id}")
      assert has_element?(tile)

      html = render(tile)
      # Sci name (italic), card id, and the available effort details.
      assert html =~ "Parus major"
      assert html =~ "##{card.id}"
      assert html =~ "TRAVEL"
      assert html =~ "08:15"
      assert html =~ "90 min"
      assert html =~ "3.5 km"
    end

    test "searching lists matching observations and adding selects one", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      live |> element("#image-observations-search") |> render_keyup(%{"value" => "great tit"})

      assert has_element?(live, "#image-observations-result-#{obs.id}")

      # The matched term is highlighted (the shared highlighter wraps it in
      # <strong>, styled here as a yellow background rather than bold).
      result_html = render(element(live, "#image-observations-result-#{obs.id}"))
      assert result_html =~ "<strong>Great Tit</strong>"

      live
      |> element("#image-observations-result-#{obs.id} button[phx-click=add_observation]")
      |> render_click()

      assert has_element?(live, "#image-observations-selected-#{obs.id}")
    end

    test "does not search on a single letter", %{conn: conn, user: user, obs: obs} do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      live |> element("#image-observations-search") |> render_keyup(%{"value" => "g"})
      refute has_element?(live, "#image-observations-result-#{obs.id}")

      live |> element("#image-observations-search") |> render_keyup(%{"value" => "gr"})
      assert has_element?(live, "#image-observations-result-#{obs.id}")
    end

    test "removing a selected observation drops its tile", %{conn: conn, user: user, obs: obs} do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      live
      |> element("#image-observations-selected-#{obs.id} button[phx-click=remove_observation]")
      |> render_click()

      refute has_element?(live, "#image-observations-selected-#{obs.id}")
    end

    test "saving persists the staged observation selection", %{conn: conn, user: user, obs: obs} do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      live |> element("#image-observations-search") |> render_keyup(%{"value" => "great tit"})

      live
      |> element("#image-observations-result-#{obs.id} button[phx-click=add_observation]")
      |> render_click()

      render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      assert_redirect(live, ~p"/my/images/#{image.id}")

      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end

    test "saving with no selection clears any existing links", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      live
      |> element("#image-observations-selected-#{obs.id} button[phx-click=remove_observation]")
      |> render_click()

      render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert reloaded.observations == []
    end
  end

  defp create_stored_image(user) do
    dest = Waffle.File.generate_temporary_path(".jpg")
    File.cp!(@sample_image, dest)

    {:ok, image} =
      Images.create_image(user, %{
        "slug" => "original-#{System.unique_integer([:positive])}",
        "file" => %Plug.Upload{path: dest, filename: "original.jpg", content_type: "image/jpeg"}
      })

    File.rm(dest)
    image
  end

  defp waffle_prefix do
    Application.get_env(:waffle, :storage_dir_prefix, "")
  end
end
