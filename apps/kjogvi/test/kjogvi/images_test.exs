defmodule Kjogvi.ImagesTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Images
  alias Kjogvi.Images.Image
  alias Kjogvi.ImagesFixtures
  alias Kjogvi.UsersFixtures

  describe "list_images/2" do
    @page %{page: 1, page_size: 20}

    test "returns only the given user's images" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      _other = ImagesFixtures.image_fixture(user: UsersFixtures.user_fixture())

      assert [returned] = Images.list_images(user, @page).entries
      assert returned.id == image.id
    end

    test "orders by inserted_at descending (newest first)" do
      user = UsersFixtures.user_fixture()
      older = ImagesFixtures.image_fixture(user: user)
      newer = ImagesFixtures.image_fixture(user: user)

      ids = Images.list_images(user, @page).entries |> Enum.map(& &1.id)
      assert ids == [newer.id, older.id]
    end

    test "paginates the results" do
      user = UsersFixtures.user_fixture()
      for _ <- 1..3, do: ImagesFixtures.image_fixture(user: user)

      page = Images.list_images(user, %{page: 1, page_size: 2})
      assert length(page.entries) == 2
      assert page.total_entries == 3
      assert page.total_pages == 2

      second = Images.list_images(user, %{page: 2, page_size: 2})
      assert length(second.entries) == 1
    end
  end

  describe "get_image!/2" do
    test "returns the user's image" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      assert Images.get_image!(user, image.id).id == image.id
    end

    test "raises when the image belongs to another user" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: UsersFixtures.user_fixture())

      assert_raise Ecto.NoResultsError, fn ->
        Images.get_image!(user, image.id)
      end
    end
  end

  describe "get_image_by_slug/1" do
    test "returns the matching image" do
      image = ImagesFixtures.image_fixture(slug: "my-test-slug")
      assert Images.get_image_by_slug("my-test-slug").id == image.id
    end

    test "returns nil when not found" do
      assert Images.get_image_by_slug("nonexistent-slug") == nil
    end
  end

  describe "update_image/2" do
    test "updates editable fields" do
      image = ImagesFixtures.image_fixture()
      assert {:ok, updated} = Images.update_image(image, %{title: "New Title"})
      assert updated.title == "New Title"
    end

    test "returns an error changeset for invalid data" do
      image = ImagesFixtures.image_fixture()
      assert {:error, %Ecto.Changeset{}} = Images.update_image(image, %{slug: ""})
    end
  end

  describe "token" do
    test "is assigned automatically and differs per image" do
      image1 = ImagesFixtures.image_fixture()
      image2 = ImagesFixtures.image_fixture()

      assert is_binary(image1.token)
      assert image1.token != ""
      assert image1.token != image2.token
    end
  end

  describe "slug uniqueness" do
    test "rejects a duplicate slug for the same user" do
      user = UsersFixtures.user_fixture()
      ImagesFixtures.image_fixture(user: user, slug: "shared-slug")

      attrs = ImagesFixtures.valid_image_attributes(user: user, slug: "shared-slug")

      assert {:error, changeset} = Repo.insert(Image.changeset(%Image{}, attrs))
      assert "has already been taken" in errors_on(changeset).slug
    end

    test "allows the same slug for different users" do
      ImagesFixtures.image_fixture(user: UsersFixtures.user_fixture(), slug: "shared-slug")
      other = UsersFixtures.user_fixture()

      assert %Image{} = ImagesFixtures.image_fixture(user: other, slug: "shared-slug")
    end
  end

  describe "url/2" do
    setup do
      previous = Application.get_env(:kjogvi, :images)

      Application.put_env(:kjogvi, :images,
        storage_backend: "s3_dev",
        hosts: %{
          "local" => nil,
          "s3_dev" => "https://dev-bucket.s3.example.com",
          # A trailing slash must not double up in the URL.
          "s3_prod" => "https://prod-bucket.s3.example.com/"
        }
      )

      on_exit(fn -> Application.put_env(:kjogvi, :images, previous) end)
    end

    # An image carrying a stored file, built without touching storage.
    defp image_with_file(user, backend) do
      %Image{
        token: "imgtok",
        slug: "pileated",
        storage_backend: backend,
        user_id: user.id,
        user: user,
        file: %{file_name: "pileated.jpg", updated_at: ~N[2026-06-03 12:00:00]}
      }
    end

    test "returns nil when the image has no stored file" do
      assert Images.url(%Image{file: nil}) == nil
    end

    test "returns the legacy URL when the image has no stored file but a legacy_url" do
      legacy = "https://old.example.com/photos/pileated.jpg"
      assert Images.url(%Image{file: nil, legacy_url: legacy}) == legacy
    end

    test "ignores the legacy URL for any requested version" do
      legacy = "https://old.example.com/photos/pileated.jpg"
      image = %Image{file: nil, legacy_url: legacy}
      assert Images.url(image, :thumbnail) == legacy
      assert Images.url(image, :original) == legacy
    end

    test "prefers the stored file over the legacy URL" do
      user = UsersFixtures.user_fixture()
      image = %{image_with_file(user, "s3_dev") | legacy_url: "https://old.example.com/x.jpg"}
      assert Images.url(image) =~ "https://dev-bucket.s3.example.com/"
    end

    test "builds an absolute URL against the image's own backend host" do
      user = UsersFixtures.user_fixture()
      url = Images.url(image_with_file(user, "s3_prod"), :medium)

      assert url ==
               "https://prod-bucket.s3.example.com" <>
                 "/uploads/images/#{user.public_token}/imgtok/pileated_medium.jpg" <>
                 "?#{expected_unix()}"
    end

    test "uses the backend recorded on the image, not the running env's backend" do
      user = UsersFixtures.user_fixture()

      # The env uploads with s3_dev (see setup), but a prod image still resolves
      # to the prod host.
      assert Images.url(image_with_file(user, "s3_prod")) =~ "https://prod-bucket.s3.example.com/"
      assert Images.url(image_with_file(user, "s3_dev")) =~ "https://dev-bucket.s3.example.com/"
    end

    test "local images get a host-relative path served by the endpoint" do
      user = UsersFixtures.user_fixture()
      url = Images.url(image_with_file(user, "local"), :medium)
      assert String.starts_with?(url, "/uploads/images/")
      refute url =~ "://"
    end

    test "names the original without a version suffix and variants with one" do
      user = UsersFixtures.user_fixture()
      assert Images.url(image_with_file(user, "s3_dev"), :original) =~ "/pileated.jpg?"
      assert Images.url(image_with_file(user, "s3_dev"), :thumbnail) =~ "/pileated_thumbnail.jpg?"
    end

    test "appends the upload timestamp as a cache-buster" do
      user = UsersFixtures.user_fixture()
      assert Images.url(image_with_file(user, "s3_dev")) =~ "?#{expected_unix()}"
    end

    defp expected_unix do
      ~N[2026-06-03 12:00:00]
      |> DateTime.from_naive!("Etc/UTC")
      |> DateTime.to_unix()
    end
  end

  describe "replace_image_file/2" do
    @sample_image Path.expand(
                    Path.join([__DIR__, "..", "support", "fixtures", "files", "sample_bird.jpg"])
                  )

    setup do
      user = UsersFixtures.user_fixture()

      {:ok, image} =
        Images.create_image(user, %{
          "slug" => "original-#{System.unique_integer([:positive])}",
          "file" => plug_upload("original.jpg")
        })

      on_exit(fn ->
        user_dir =
          Path.join([
            Application.get_env(:waffle, :storage_dir_prefix, ""),
            "uploads/images",
            user.public_token
          ])

        File.rm_rf!(user_dir)
      end)

      %{user: user, image: image}
    end

    test "stores the new file and re-stamps the storage backend", %{image: image} do
      assert {:ok, replaced} =
               Images.replace_image_file(image, %{"file" => plug_upload("replacement.jpg")})

      assert replaced.id == image.id
      assert replaced.file.file_name == "replacement.jpg"
      assert replaced.storage_backend == "local"

      assert File.exists?(stored_path(replaced, "replacement.jpg"))

      for version <- ~w(thumbnail small medium large) do
        assert File.exists?(stored_path(replaced, "replacement_#{version}.jpg"))
      end
    end

    test "re-extracts dimensions and EXIF date from the new file", %{image: image} do
      # Wipe extras first so we can prove they come back from the new upload.
      {:ok, image} = image |> Image.metadata_changeset(%{}) |> Repo.update()
      assert image.extras == %{}

      assert {:ok, replaced} =
               Images.replace_image_file(image, %{"file" => plug_upload("replacement.jpg")})

      assert replaced.extras["width"] == 60
      assert replaced.extras["height"] == 40
      assert replaced.extras["exif_date"] == "2021-07-15 09:30:00"
    end

    test "uses passed-in extras instead of re-reading the file", %{image: image} do
      extras = %{"width" => 1, "height" => 2, "exif_date" => "1999-12-31 00:00:00"}

      assert {:ok, replaced} =
               Images.replace_image_file(
                 image,
                 %{"file" => plug_upload("replacement.jpg")},
                 extras
               )

      # The supplied extras are stored verbatim, not the actual file's metadata.
      assert replaced.extras == extras
    end

    test "leaves the previous stored objects in place", %{image: image} do
      original_path = stored_path(image, "original.jpg")
      assert File.exists?(original_path)

      assert {:ok, _replaced} =
               Images.replace_image_file(image, %{"file" => plug_upload("replacement.jpg")})

      # The differently-named original is not deleted.
      assert File.exists?(original_path)
    end

    defp plug_upload(name) do
      dest = Waffle.File.generate_temporary_path(".jpg")
      File.cp!(@sample_image, dest)
      %Plug.Upload{path: dest, filename: name, content_type: "image/jpeg"}
    end

    defp stored_path(image, file_name) do
      Path.join([
        Application.get_env(:waffle, :storage_dir_prefix, ""),
        "uploads/images",
        image.user.public_token,
        image.token,
        file_name
      ])
    end
  end

  describe "delete_image/1" do
    test "removes the image" do
      image = ImagesFixtures.image_fixture()
      assert {:ok, _} = Images.delete_image(image)
      assert Repo.get(Image, image.id) == nil
    end
  end

  describe "attach_observations/2" do
    test "links observations from the same card" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs1 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")
      obs2 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "canwoo1")

      assert {:ok, updated} = Images.attach_observations(image, [obs1.id, obs2.id])

      obs_ids = updated.observations |> Enum.map(& &1.id) |> Enum.sort()
      assert obs_ids == Enum.sort([obs1.id, obs2.id])
    end

    test "sets multi_species based on the number of attached observations" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs1 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")
      obs2 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "canwoo1")

      assert {:ok, updated} = Images.attach_observations(image, [obs1.id, obs2.id])
      assert updated.multi_species == true
      assert Kjogvi.Repo.reload(image).multi_species == true

      assert {:ok, updated} = Images.attach_observations(image, [obs1.id])
      assert updated.multi_species == false
      assert Kjogvi.Repo.reload(image).multi_species == false
    end

    test "returns an error changeset when observations span different cards" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      card1 = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      card2 = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs1 = Kjogvi.Factory.insert(:observation, card: card1, taxon_key: "mallar1")
      obs2 = Kjogvi.Factory.insert(:observation, card: card2, taxon_key: "canwoo1")

      assert {:error, changeset} = Images.attach_observations(image, [obs1.id, obs2.id])
      assert "must all belong to the same card" in errors_on(changeset).observations
    end

    test "returns an error changeset (and keeps existing links) for an empty list" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")

      {:ok, _} = Images.attach_observations(image, [obs.id])

      assert {:error, changeset} = Images.attach_observations(image, [])
      assert "can't be empty" in errors_on(changeset).observations

      # The failed update left the existing link untouched.
      reloaded = Kjogvi.Repo.preload(image, :observations, force: true)
      assert Enum.map(reloaded.observations, & &1.id) == [obs.id]
    end

    test "ignores observation ids belonging to another user's cards" do
      user = UsersFixtures.user_fixture()
      other_user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)

      mine = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      my_obs = Kjogvi.Factory.insert(:observation, card: mine, taxon_key: "mallar1")

      theirs =
        Kjogvi.Factory.insert(:card, user: other_user, location: Kjogvi.Factory.insert(:location))

      their_obs = Kjogvi.Factory.insert(:observation, card: theirs, taxon_key: "canwoo1")

      # The foreign id is dropped, so only the owner's observation is linked —
      # and crucially it doesn't trip the same-card check against the foreign one.
      assert {:ok, updated} = Images.attach_observations(image, [my_obs.id, their_obs.id])
      assert Enum.map(updated.observations, & &1.id) == [my_obs.id]
    end

    test "errors when every id belongs to another user (nothing left to link)" do
      user = UsersFixtures.user_fixture()
      other_user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)

      theirs =
        Kjogvi.Factory.insert(:card, user: other_user, location: Kjogvi.Factory.insert(:location))

      their_obs = Kjogvi.Factory.insert(:observation, card: theirs, taxon_key: "mallar1")

      assert {:error, changeset} = Images.attach_observations(image, [their_obs.id])
      assert "can't be empty" in errors_on(changeset).observations
    end
  end

  describe "list_images_for_card/1" do
    test "returns images linked to the card's observations" do
      user = UsersFixtures.user_fixture()
      card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs.id])

      assert Images.list_images_for_card(card.id) |> Enum.map(& &1.id) == [image.id]
    end

    test "excludes images from other cards" do
      user = UsersFixtures.user_fixture()
      card1 = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      card2 = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs2 = Kjogvi.Factory.insert(:observation, card: card2, taxon_key: "mallar1")
      image = ImagesFixtures.image_fixture(user: user)
      {:ok, _} = Images.attach_observations(image, [obs2.id])

      assert Images.list_images_for_card(card1.id) == []
    end
  end

  describe "get_observations_for_display/2" do
    test "hydrates observations with taxon, card, and location, preserving id order" do
      user = UsersFixtures.user_fixture()
      location = Kjogvi.Factory.insert(:location)
      card = Kjogvi.Factory.insert(:card, user: user, location: location)
      obs1 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")
      obs2 = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "canwoo1")

      assert [first, second] = Images.get_observations_for_display(user, [obs2.id, obs1.id])
      assert first.id == obs2.id
      assert second.id == obs1.id
      assert first.card.location.id == location.id
      # taxon/species virtuals are populated (nil taxon when key is unknown)
      assert Map.has_key?(first, :taxon)
    end

    test "excludes observations belonging to another user" do
      user = UsersFixtures.user_fixture()
      other_card = Kjogvi.Factory.insert(:card, location: Kjogvi.Factory.insert(:location))
      other_obs = Kjogvi.Factory.insert(:observation, card: other_card, taxon_key: "mallar1")

      assert Images.get_observations_for_display(user, [other_obs.id]) == []
    end

    test "returns an empty list for an empty id list" do
      user = UsersFixtures.user_fixture()
      assert Images.get_observations_for_display(user, []) == []
    end
  end

  describe "search_observations_for_image/2" do
    setup do
      book = Ornitho.Factory.insert(:book, slug: "ebird", version: "v2024")

      Ornitho.Factory.insert(:taxon,
        book: book,
        code: "gretit1",
        name_en: "Great Tit",
        name_sci: "Parus major"
      )

      {:ok, user} =
        UsersFixtures.user_fixture()
        |> Kjogvi.Users.update_user_settings(%{"default_book_signature" => "ebird/v2024"})

      %{user: user}
    end

    test "returns an empty list for a blank query", %{user: user} do
      assert Images.search_observations_for_image(user, %{query: ""}) == []
      assert Images.search_observations_for_image(user, %{query: "  "}) == []
    end

    test "returns the user's observations of taxa matching the typed text", %{user: user} do
      location = Kjogvi.Factory.insert(:location)
      card = Kjogvi.Factory.insert(:card, user: user, location: location)

      obs =
        Kjogvi.Factory.insert(:observation, card: card, taxon_key: "/ebird/v2024/gretit1")

      assert [found] = Images.search_observations_for_image(user, %{query: "great tit"})
      assert found.id == obs.id
      assert found.card.location.id == location.id
    end

    test "with a date set, restricts results to observations on that day", %{user: user} do
      location = Kjogvi.Factory.insert(:location)

      on_date =
        Kjogvi.Factory.insert(:card,
          user: user,
          location: location,
          observ_date: ~D[2024-05-12]
        )

      off_date =
        Kjogvi.Factory.insert(:card,
          user: user,
          location: location,
          observ_date: ~D[2024-05-13]
        )

      on_obs =
        Kjogvi.Factory.insert(:observation, card: on_date, taxon_key: "/ebird/v2024/gretit1")

      _off_obs =
        Kjogvi.Factory.insert(:observation, card: off_date, taxon_key: "/ebird/v2024/gretit1")

      results =
        Images.search_observations_for_image(user, %{query: "great tit", date: ~D[2024-05-12]})

      assert Enum.map(results, & &1.id) == [on_obs.id]
    end

    test "with a card_id set, restricts results to that one card", %{user: user} do
      location = Kjogvi.Factory.insert(:location)
      this_card = Kjogvi.Factory.insert(:card, user: user, location: location)
      other_card = Kjogvi.Factory.insert(:card, user: user, location: location)

      on_card =
        Kjogvi.Factory.insert(:observation, card: this_card, taxon_key: "/ebird/v2024/gretit1")

      _off_card =
        Kjogvi.Factory.insert(:observation, card: other_card, taxon_key: "/ebird/v2024/gretit1")

      results =
        Images.search_observations_for_image(user, %{
          query: "great tit",
          card_id: this_card.id
        })

      assert Enum.map(results, & &1.id) == [on_card.id]
    end

    test "card_id takes precedence over date", %{user: user} do
      location = Kjogvi.Factory.insert(:location)

      card =
        Kjogvi.Factory.insert(:card, user: user, location: location, observ_date: ~D[2024-05-12])

      obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "/ebird/v2024/gretit1")

      # A non-matching date is ignored once the search is scoped to a card.
      results =
        Images.search_observations_for_image(user, %{
          query: "great tit",
          card_id: card.id,
          date: ~D[2024-01-01]
        })

      assert Enum.map(results, & &1.id) == [obs.id]
    end

    test "excludes another user's observations", %{user: user} do
      other_user = UsersFixtures.user_fixture()

      card =
        Kjogvi.Factory.insert(:card, user: other_user, location: Kjogvi.Factory.insert(:location))

      _obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "/ebird/v2024/gretit1")

      assert Images.search_observations_for_image(user, %{query: "great tit"}) == []
    end
  end

  describe "extract_metadata/1" do
    @sample_image Path.expand(
                    Path.join([__DIR__, "..", "support", "fixtures", "files", "sample_bird.jpg"])
                  )

    test "reads dimensions and EXIF date from an uploaded file" do
      upload = %Plug.Upload{
        path: @sample_image,
        filename: "sample_bird.jpg",
        content_type: "image/jpeg"
      }

      assert %{"width" => 60, "height" => 40, "exif_date" => "2021-07-15 09:30:00"} =
               Images.extract_metadata(upload)
    end

    test "returns an empty map for a non-upload" do
      assert Images.extract_metadata(nil) == %{}
    end
  end

  describe "exif_date/1" do
    test "returns the capture date from an extras map" do
      assert Images.exif_date(%{"exif_date" => "2021-07-15 09:30:00"}) == ~D[2021-07-15]
    end

    test "returns nil when the extras map has no parseable date" do
      assert Images.exif_date(%{}) == nil
      assert Images.exif_date(%{"exif_date" => "not a date"}) == nil
    end
  end

  describe "Image.dimensions/1 and Image.exif_date/1" do
    test "dimensions reads width and height from extras" do
      assert Image.dimensions(%Image{extras: %{"width" => 1200, "height" => 800}}) == {1200, 800}
      assert Image.dimensions(%Image{extras: %{}}) == nil
    end

    test "exif_date parses a stored capture timestamp" do
      image = %Image{extras: %{"exif_date" => "2025-05-25 18:50:14"}}
      assert Image.exif_date(image) == ~N[2025-05-25 18:50:14]
    end

    test "exif_date returns nil when absent or unparseable" do
      assert Image.exif_date(%Image{extras: %{}}) == nil
      assert Image.exif_date(%Image{extras: %{"exif_date" => "nonsense"}}) == nil
    end
  end
end
