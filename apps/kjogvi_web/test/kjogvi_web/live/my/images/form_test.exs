defmodule KjogviWeb.Live.My.Images.FormTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.AccountsFixtures

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
    %{conn: login_user(conn, user), user: user}
  end

  describe "new" do
    test "renders the upload drop zone", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      assert has_element?(live, "h1", "Add Image")
      assert has_element?(live, "#upload-drop-zone")
    end

    test "shows an Images breadcrumb", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      assert has_element?(live, "#image-breadcrumbs a[href='/my/images']", "Images")
      assert has_element?(live, "#image-breadcrumbs", "Add")
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
      # An image must have an observation; the sample's EXIF date (2021-07-15)
      # scopes the picker, so the observation must be on a checklist of that day.
      %{user: user} = seed_observation(user, observ_date: ~D[2021-07-15])

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

      picker_search(live, "great tit")
      picker_add_first(live)

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
        Kjogvi.Accounts.update_user_settings(user, %{"default_book_signature" => "ebird/v2024"})

      # The sample image's EXIF capture date (2021-07-15) prefills the picker's
      # date, which scopes the search — so the matching observation must be on a
      # checklist of that day to surface in the dropdown.
      checklist =
        Kjogvi.Factory.insert(:checklist,
          user: user,
          location: Kjogvi.Factory.insert(:location),
          observ_date: ~D[2021-07-15]
        )

      obs =
        Kjogvi.Factory.insert(:observation,
          checklist: checklist,
          taxon_key: "/ebird/v2024/gretit1"
        )

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

      picker_search(live, "great tit")
      picker_add_first(live)

      render_submit(live, "save", %{"image" => %{"slug" => slug}})

      image = Images.get_image_by_slug(slug) |> Kjogvi.Repo.preload(:observations)
      assert_redirect(live, ~p"/my/images/#{image.id}")
      assert Enum.map(image.observations, & &1.id) == [obs.id]
    end

    test "saving without an observation is rejected and creates nothing", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      # The required message stands as soon as the metadata form appears.
      slug = "no-obs-#{System.unique_integer([:positive])}"

      upload =
        file_input(live, "#image-form", :image, [
          %{name: "#{slug}.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "#{slug}.jpg")
      assert has_element?(live, "#image-observations-required")

      html = render_submit(live, "save", %{"image" => %{"slug" => slug}})

      assert html =~ "at least one observation"
      assert Images.get_image_by_slug(slug) == nil
    end

    test "a tampered cross-checklist save leaves no orphan image behind", %{
      conn: conn,
      user: user
    } do
      # Two observations on different cards — the picker can't stage this, but a
      # tampered client could push it to the LiveView.
      %{user: user, obs: obs1} = seed_observation(user)

      card2 =
        Kjogvi.Factory.insert(:checklist, user: user, location: Kjogvi.Factory.insert(:location))

      obs2 =
        Kjogvi.Factory.insert(:observation, checklist: card2, taxon_key: "/ebird/v2024/gretit1")

      {:ok, live, _html} = live(conn, ~p"/my/images/new")

      slug = "tampered-#{System.unique_integer([:positive])}"

      upload =
        file_input(live, "#image-form", :image, [
          %{name: "#{slug}.jpg", content: File.read!(@sample_image), type: "image/jpeg"}
        ])

      render_upload(upload, "#{slug}.jpg")

      user_dir = Path.join([waffle_prefix(), "uploads/images", user.public_token])
      on_exit(fn -> File.rm_rf!(user_dir) end)

      send(live.pid, {:image_observations_changed, [obs1.id, obs2.id]})

      html = render_submit(live, "save", %{"image" => %{"slug" => slug}})

      assert html =~ "couldn&#39;t be attached"
      # The image created moments earlier was rolled back, not left orphaned.
      assert Images.get_image_by_slug(slug) == nil
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
      # An image must have an observation to be saved.
      %{obs: obs} = seed_observation(user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

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
      # An image must have an observation to be saved.
      %{obs: obs} = seed_observation(user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

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
        Kjogvi.Accounts.update_user_settings(user, %{"default_book_signature" => "ebird/v2024"})

      location = Kjogvi.Factory.insert(:location)

      checklist =
        Kjogvi.Factory.insert(:checklist,
          user: user,
          location: location,
          effort_type: "TRAVEL",
          start_time: ~T[08:15:00],
          duration_minutes: 90,
          distance_kms: 3.5
        )

      obs =
        Kjogvi.Factory.insert(:observation,
          checklist: checklist,
          taxon_key: "/ebird/v2024/gretit1"
        )

      %{user: user, checklist: checklist, obs: obs}
    end

    test "uploading a replacement does not override the date when observations exist", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # Seeded from the attached observation's checklist (factory default 2023-08-29),
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
      checklist: checklist,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      tile = element(live, "#image-observations-selected-#{obs.id}")
      assert has_element?(tile)

      html = render(tile)
      # Sci name (italic), checklist id, and the available effort details.
      assert html =~ "Parus major"
      assert html =~ "##{checklist.id}"
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

      picker_search(live, "great tit")

      assert has_element?(live, "#image-observations-search-result-0")

      # The matched term is highlighted (the shared highlighter wraps it in
      # <strong>, styled here as a yellow background rather than bold).
      result_html = render(element(live, "#image-observations-search-result-0"))
      assert result_html =~ "<strong>Great Tit</strong>"

      picker_add_first(live)

      assert has_element?(live, "#image-observations-selected-#{obs.id}")
    end

    test "does not search on a single letter", %{conn: conn, user: user} do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      picker_search(live, "g")
      refute has_element?(live, "#image-observations-search-result-0")

      picker_search(live, "gr")
      assert has_element?(live, "#image-observations-search-result-0")
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

      picker_search(live, "great tit")
      picker_add_first(live)

      render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      assert_redirect(live, ~p"/my/images/#{image.id}")

      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end

    test "removing all observations shows the required message", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")
      refute has_element?(live, "#image-observations-required")

      live
      |> element("#image-observations-selected-#{obs.id} button[phx-click=remove_observation]")
      |> render_click()

      assert has_element?(live, "#image-observations-required")
    end

    test "saving with no observations is rejected and keeps existing links", %{
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

      html =
        render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      # Stayed on the form with an error, and the prior link is untouched.
      assert html =~ "at least one observation"

      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end

    test "selecting an observation locks the date field to its checklist date", %{
      conn: conn,
      user: user
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # Editable while nothing is selected.
      refute has_element?(live, "#image-observations-date[disabled]")

      picker_search(live, "great tit")
      picker_add_first(live)

      # Locked to the selected observation's checklist date (factory default).
      assert has_element?(live, "#image-observations-date[disabled][value='2023-08-29']")
      assert has_element?(live, "#image-observations-date-locked")
    end

    test "removing the last observation re-enables the date field", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")
      assert has_element?(live, "#image-observations-date[disabled]")

      live
      |> element("#image-observations-selected-#{obs.id} button[phx-click=remove_observation]")
      |> render_click()

      refute has_element?(live, "#image-observations-date[disabled]")
      refute has_element?(live, "#image-observations-date-locked")
    end

    test "once a checklist is locked, search is restricted to that checklist", %{
      conn: conn,
      user: user,
      checklist: checklist
    } do
      # A second observation of the same taxon on the same day, but a different
      # checklist — so the date scope alone keeps both, and only locking the checklist
      # narrows it down.
      other_card =
        Kjogvi.Factory.insert(:checklist, user: user, observ_date: checklist.observ_date)

      Kjogvi.Factory.insert(:observation,
        checklist: other_card,
        taxon_key: "/ebird/v2024/gretit1"
      )

      image = ImagesFixtures.image_fixture(user: user)
      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # Scope the picker to the shared day; both cards' observations show as two
      # rows (keyed by position).
      live
      |> element("#image-observations-date")
      |> render_change(%{"date" => Date.to_iso8601(checklist.observ_date)})

      picker_search(live, "great tit")
      assert has_element?(live, "#image-observations-search-result-0")
      assert has_element?(live, "#image-observations-search-result-1")

      # Pick the first; its checklist is now locked.
      picker_add_first(live)

      # Search again: only the locked checklist's single observation remains.
      picker_search(live, "great tit")
      assert has_element?(live, "#image-observations-search-result-0")
      refute has_element?(live, "#image-observations-search-result-1")
    end

    test "an already-attached search result is shown dimmed and re-adding is a no-op", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      picker_search(live, "great tit")

      # The only matching observation is already attached: its row is dimmed and
      # flagged.
      result_html = render(element(live, "#image-observations-search-result-0"))
      assert result_html =~ "opacity-50"
      assert result_html =~ "Already attached"

      # Re-picking it does not stage a duplicate; the single tile stands.
      picker_add_first(live)

      assert has_element?(live, "#image-observations-selected-#{obs.id}")

      selected_count =
        live
        |> element("#image-observations-selected")
        |> render()
        |> Floki.parse_fragment!()
        |> Floki.find("li")
        |> length()

      assert selected_count == 1
    end

    # The picker UI can't stage cross-checklist ids (search locks to one checklist), but a
    # tampered/buggy client could push them to the LiveView directly. The save
    # must reject it rather than silently claim success.
    test "a save with staged cross-checklist ids is rejected, not silently dropped", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      other_card =
        Kjogvi.Factory.insert(:checklist, user: user, location: Kjogvi.Factory.insert(:location))

      other_obs =
        Kjogvi.Factory.insert(:observation,
          checklist: other_card,
          taxon_key: "/ebird/v2024/gretit1"
        )

      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # Simulate a tampered client staging observations from two different cards.
      send(live.pid, {:image_observations_changed, [obs.id, other_obs.id]})

      html =
        render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      # Stayed on the form with an error; no false success, no redirect.
      assert html =~ "couldn&#39;t be attached"
      refute_redirected(live, ~p"/my/images/#{image.id}")

      # The pre-existing single link is untouched.
      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end

    test "a save with another user's observation id is rejected", %{
      conn: conn,
      user: user,
      obs: obs
    } do
      other_user = user_fixture()

      foreign_card =
        Kjogvi.Factory.insert(:checklist,
          user: other_user,
          location: Kjogvi.Factory.insert(:location)
        )

      foreign_obs =
        Kjogvi.Factory.insert(:observation,
          checklist: foreign_card,
          taxon_key: "/ebird/v2024/gretit1"
        )

      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      {:ok, live, _html} = live(conn, ~p"/my/images/#{image.id}/edit")

      # A tampered client stages only a foreign id.
      send(live.pid, {:image_observations_changed, [foreign_obs.id]})

      html =
        render_submit(live, "save", %{"image" => %{"slug" => image.slug, "sort_order" => "100"}})

      assert html =~ "couldn&#39;t be attached"

      # The foreign observation was never linked; the prior link stands.
      reloaded = Images.get_image!(user, image.id) |> Kjogvi.Repo.preload(:observations)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end
  end

  # Sets up the default taxonomy book/taxon used by the picker and returns an
  # observation on a checklist belonging to `user`. Tests that must satisfy the
  # "image needs an observation" rule attach or select this.
  defp seed_observation(user, opts \\ []) do
    book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

    Ornitho.Factory.insert(:taxon,
      book: book,
      code: "gretit1",
      name_en: "Great Tit",
      name_sci: "Parus major"
    )

    {:ok, user} =
      Kjogvi.Accounts.update_user_settings(user, %{"default_book_signature" => "ebird/v2024"})

    checklist =
      Kjogvi.Factory.insert(
        :checklist,
        Keyword.merge([user: user, location: Kjogvi.Factory.insert(:location)], opts)
      )

    obs =
      Kjogvi.Factory.insert(:observation, checklist: checklist, taxon_key: "/ebird/v2024/gretit1")

    %{user: user, checklist: checklist, obs: obs}
  end

  # Types a query into the picker's autocomplete (the embedded
  # `Autocomplete` lives at `#image-observations-search`).
  defp picker_search(live, query) do
    live |> element("#image-observations-search") |> render_keyup(%{"value" => query})
  end

  # Clicks the first dropdown result row, committing that observation. The
  # `Autocomplete` keys its rows by position, so the first match is row 0.
  defp picker_add_first(live) do
    live |> element("#image-observations-search-result-0") |> render_click()
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
