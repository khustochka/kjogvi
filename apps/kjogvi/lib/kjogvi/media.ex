defmodule Kjogvi.Media do
  @moduledoc """
  Context for operations with media.
  """

  alias Kjogvi.Media.Image
  alias Kjogvi.Repo

  def get_image(scope, slug) do
    Image
    |> Image.by_user_and_slug(scope.user, slug)
    |> Repo.one!()
  end

  def create_image(scope, image_params) do
    Image.changeset(%Image{user: scope.user}, image_params)
    |> Repo.insert()
  end
end
