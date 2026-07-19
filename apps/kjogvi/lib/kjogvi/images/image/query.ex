defmodule Kjogvi.Images.Image.Query do
  @moduledoc """
  Queries for Image.
  """

  import Ecto.Query

  alias Kjogvi.Images.Image

  @doc """
  Base query with the owning user preloaded for display.
  """
  def base do
    from i in Image, as: :image, preload: :user
  end

  @doc """
  Restricts to images owned by `user`.
  """
  def for_user(query, %{id: user_id}) do
    where(query, [image: i], i.user_id == ^user_id)
  end

  @doc """
  Orders newest first.
  """
  def newest_first(query) do
    order_by(query, [image: i], desc: i.inserted_at, desc: i.id)
  end
end
