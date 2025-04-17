defmodule Kjogvi.Attachments.PhotoAttachment do
  @moduledoc """
  Attachment representation for Image photo.
  """

  use Waffle.Definition
  use Waffle.Ecto.Definition

  def filename(_version, {_photo, image}) do
    image.slug
  end

  def storage_dir(_version, {_photo, _image}) do
    "uploads/photos"
  end
end
