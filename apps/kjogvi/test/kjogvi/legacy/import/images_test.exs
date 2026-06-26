defmodule Kjogvi.Legacy.Import.ImagesTest do
  # Not async: `Images.import/3` calls `setval('images_id_seq', ...)`, a
  # non-transactional, database-global side effect the SQL sandbox cannot roll
  # back or isolate. See Kjogvi.Legacy.Import.ObservationsTest for details.
  use Kjogvi.DataCase, async: false

  import Kjogvi.Factory

  alias Kjogvi.Legacy.Import.Images
  alias Kjogvi.Images.Image
  alias Kjogvi.Images.ImageObservation
  alias Kjogvi.Repo

  @columns ~w(
    id slug title description index_num multi_species
    media_type status assets_cache external_id spot_id
    created_at updated_at original_url observation_ids
  )

  defp row(overrides \\ %{}) do
    base = %{
      "id" => 1,
      "slug" => "a-photo",
      "title" => "Legacy Title",
      "description" => "a description",
      "index_num" => 1000,
      "multi_species" => false,
      "media_type" => "photos",
      "status" => "PUBLIC",
      "assets_cache" => "cache-blob",
      "external_id" => "ext-1",
      "spot_id" => 42,
      "created_at" => "2026-01-02T03:04:05Z",
      "updated_at" => "2026-01-03T03:04:05Z",
      "original_url" => "https://example.com/orig.jpg",
      "observation_ids" => []
    }

    values = Map.merge(base, overrides)
    Enum.map(@columns, &Map.fetch!(values, &1))
  end

  describe "import/3" do
    test "maps legacy media columns onto the image" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row()], user: user)

      [image] = Repo.all(Image)
      assert image.id == 1
      assert image.slug == "a-photo"
      assert image.description == "a description"
      assert image.sort_order == 1000
      assert image.multi_species == false
      assert image.user_id == user.id
      assert image.storage_backend == "legacy"
      assert image.import_source == :legacy
      assert image.legacy_url == "https://example.com/orig.jpg"
      assert is_binary(image.token)
    end

    test "leaves title blank and stashes the legacy title in extras" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row()], user: user)

      [image] = Repo.all(Image)
      assert image.title == nil
      assert image.extras["legacy_title"] == "Legacy Title"
    end

    test "does not store a blank legacy title in extras" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row(%{"title" => "   "})], user: user)

      [image] = Repo.all(Image)
      refute Map.has_key?(image.extras, "legacy_title")
    end

    test "leaves a blank description as nil" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row(%{"description" => "   "})], user: user)

      [image] = Repo.all(Image)
      assert image.description == nil
    end

    test "preserves unmapped legacy columns under extras" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row()], user: user)

      [image] = Repo.all(Image)
      assert image.extras["status"] == "PUBLIC"
      assert image.extras["assets_cache"] == "cache-blob"
      assert image.extras["external_id"] == "ext-1"
      assert image.extras["spot_id"] == 42
    end

    test "converts legacy timestamps into the image timestamps" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row()], user: user)

      [image] = Repo.all(Image)
      assert image.inserted_at == ~U[2026-01-02 03:04:05.000000Z]
      assert image.updated_at == ~U[2026-01-03 03:04:05.000000Z]
    end

    test "rebuilds image<->observation join rows from observation_ids" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      checklist = insert(:checklist, user: user)
      obs1 = insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")
      obs2 = insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/bkcchi1")

      Images.import(@columns, [row(%{"observation_ids" => [obs1.id, obs2.id]})], user: user)

      [image] = Repo.all(Image)

      observation_ids =
        ImageObservation
        |> Repo.all()
        |> Enum.filter(&(&1.image_id == image.id))
        |> Enum.map(& &1.observation_id)
        |> Enum.sort()

      assert observation_ids == Enum.sort([obs1.id, obs2.id])
    end

    test "creates no join rows when observation_ids is empty" do
      user = Kjogvi.AccountsFixtures.user_fixture()

      Images.import(@columns, [row(%{"observation_ids" => []})], user: user)

      assert Repo.aggregate(ImageObservation, :count) == 0
    end

    test "raises when no :user option is provided" do
      assert_raise ArgumentError, ~r/requires a :user option/, fn ->
        Images.import(@columns, [row()], [])
      end
    end
  end

  describe "cleanup/0" do
    test "deletes legacy-imported images and their join rows" do
      user = Kjogvi.AccountsFixtures.user_fixture()
      checklist = insert(:checklist, user: user)
      obs = insert(:observation, checklist: checklist, taxon_key: "ebird/eBird_2023/amecro")

      Images.import(@columns, [row(%{"observation_ids" => [obs.id]})], user: user)
      assert Repo.aggregate(Image, :count) == 1
      assert Repo.aggregate(ImageObservation, :count) == 1

      assert {:ok, _} = Images.cleanup()
      assert Repo.aggregate(Image, :count) == 0
      assert Repo.aggregate(ImageObservation, :count) == 0
    end
  end

  describe "after_import/0" do
    test "is a no-op" do
      assert :ok = Images.after_import()
    end
  end
end
