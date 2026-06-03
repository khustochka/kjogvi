defmodule Kjogvi.ImagesFixtures do
  @moduledoc """
  Test helpers for creating images.
  """

  alias Kjogvi.Images.Image
  alias Kjogvi.Repo

  def valid_image_attributes(attrs \\ %{}) do
    user = attrs[:user] || Kjogvi.UsersFixtures.user_fixture()

    Enum.into(attrs, %{
      slug: "test-image-#{System.unique_integer([:positive])}",
      title: "Test Image",
      description: "A test image",
      sort_order: 100,
      storage_backend: "local",
      user_id: user.id
    })
  end

  @doc """
  Inserts an image without a stored file (for testing metadata and
  associations).
  """
  def image_fixture(attrs \\ %{}) do
    {:ok, image} =
      attrs
      |> valid_image_attributes()
      |> then(&Repo.insert(Image.changeset(%Image{}, &1)))

    image
  end
end
