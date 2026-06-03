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
