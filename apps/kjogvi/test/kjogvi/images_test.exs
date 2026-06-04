defmodule Kjogvi.ImagesTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Images
  alias Kjogvi.Images.Image
  alias Kjogvi.ImagesFixtures
  alias Kjogvi.UsersFixtures

  describe "list_images/1" do
    test "returns only the given user's images" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      _other = ImagesFixtures.image_fixture(user: UsersFixtures.user_fixture())

      assert [returned] = Images.list_images(user)
      assert returned.id == image.id
    end

    test "orders by sort_order then id" do
      user = UsersFixtures.user_fixture()
      img_b = ImagesFixtures.image_fixture(user: user, sort_order: 200)
      img_a = ImagesFixtures.image_fixture(user: user, sort_order: 50)
      img_c = ImagesFixtures.image_fixture(user: user, sort_order: 200)

      ids = Images.list_images(user) |> Enum.map(& &1.id)
      assert ids == [img_a.id, img_b.id, img_c.id]
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

    test "clears links when given an empty list" do
      user = UsersFixtures.user_fixture()
      image = ImagesFixtures.image_fixture(user: user)
      card = Kjogvi.Factory.insert(:card, user: user, location: Kjogvi.Factory.insert(:location))
      obs = Kjogvi.Factory.insert(:observation, card: card, taxon_key: "mallar1")

      {:ok, _} = Images.attach_observations(image, [obs.id])
      assert {:ok, updated} = Images.attach_observations(image, [])
      assert updated.observations == []
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
