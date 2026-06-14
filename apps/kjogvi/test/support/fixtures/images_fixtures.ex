defmodule Kjogvi.ImagesFixtures do
  @moduledoc """
  Test helpers for creating images.
  """

  alias Kjogvi.Images.Image
  alias Kjogvi.Repo

  def valid_image_attributes(attrs \\ %{}) do
    user = attrs[:user] || Kjogvi.AccountsFixtures.user_fixture()

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
  associations). The `:extras` map, if given, is applied directly since it is
  not user-editable through the regular changeset.
  """
  def image_fixture(attrs \\ %{}) do
    attrs = valid_image_attributes(attrs)
    {extras, attrs} = Map.pop(attrs, :extras, %{})

    {:ok, image} =
      %Image{}
      |> Image.changeset(attrs)
      |> Image.metadata_changeset(extras)
      |> Repo.insert()

    image
  end
end
