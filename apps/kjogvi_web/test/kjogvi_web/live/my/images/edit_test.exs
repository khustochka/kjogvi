defmodule KjogviWeb.Live.My.Images.EditTest do
  use KjogviWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Kjogvi.UsersFixtures

  alias Kjogvi.Images
  alias Kjogvi.ImagesFixtures

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

  describe "replace file" do
    test "hides the replace form until the replace action is started", %{conn: conn, user: user} do
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
  end

  describe "observations" do
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

      live
      |> element("#image-observations-result-#{obs.id} button[phx-click=add_observation]")
      |> render_click()

      assert has_element?(live, "#image-observations-selected-#{obs.id}")
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

    test "saving with no selection clears any existing links", %{conn: conn, user: user, obs: obs} do
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
