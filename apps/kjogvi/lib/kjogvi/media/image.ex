defmodule Kjogvi.Media.Image do
  @moduledoc """
  Image schema.
  """

  use Kjogvi.Schema
  use Waffle.Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query

  schema "images" do
    field :slug, :string
    field :photo, Kjogvi.Attachments.PhotoAttachment.Type
    field :status, :string
    field :extras, :map, default: %{}

    belongs_to(:user, Kjogvi.Users.User)

    timestamps()
  end

  def changeset(image, params \\ :invalid) do
    image
    |> cast(params, [:slug])
    |> cast_attachments(params, [:photo])
    |> unique_constraint([:user_id, :slug])
    |> validate_required([:slug, :photo, :user_id])
  end

  def by_user(query, %{id: user_id} = _user) do
    from img in query, where: img.user_id == ^user_id
  end

  def by_user_and_slug(query, user, slug) do
    query
    |> by_user(user)
    |> where(slug: ^slug)
  end
end
