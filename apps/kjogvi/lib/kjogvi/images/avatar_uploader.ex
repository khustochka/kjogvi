defmodule Kjogvi.Images.AvatarUploader do
  @moduledoc """
  Waffle uploader for user profile avatars.

  Unlike `Kjogvi.Images.Uploader`, the original upload is not kept: the single
  stored version is resized to fit within a 512×512 box (never upscaled)
  and re-encoded as JPEG, under the fixed name `avatar.jpg` — the stored key
  is fully determined by the owning user, independent of the uploaded file's
  name or format.
  """

  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:avatar]

  @max_dimension 512

  # See the corresponding notes in `Kjogvi.Images.Uploader`: images are served
  # via public, unsigned URLs (S3 only), and although the avatar key is reused
  # across re-uploads, waffle's URL timestamp busts caches on replacement.
  @acl :public_read
  @cache_control "public, max-age=31536000, immutable"

  def s3_object_headers(_version, {_file, _scope}) do
    [
      content_type: "image/jpeg",
      cache_control: @cache_control,
      content_disposition: "inline"
    ]
  end

  @doc """
  The storage key (path relative to the backend root) for the avatar,
  independent of the configured storage engine — see
  `Kjogvi.Images.Uploader.s3_key/2`.
  """
  def s3_key(version, {file, scope}) do
    Path.join(
      storage_dir(version, {file, scope}),
      Waffle.Definition.Versioning.resolve_file_name(__MODULE__, version, {file, scope})
    )
  end

  # Avatars run through the same vips pipeline as photos, so the same source
  # formats are accepted.
  def validate({file, _scope}) do
    ext = file.file_name |> Path.extname() |> String.downcase()

    if ext in Kjogvi.Images.Uploader.accepted_extensions() do
      :ok
    else
      {:error, "Invalid file type. Only images are accepted."}
    end
  end

  # The extension function pins the stored name to `.jpg` (waffle would
  # otherwise keep the upload's own extension), matching the JPEG bytes the
  # resizer writes.
  def transform(:avatar, _) do
    {&resize/2, fn _version, _file -> "jpg" end}
  end

  defp resize(:avatar, %Waffle.File{} = file) do
    case Kjogvi.Images.VixProcessor.resize_to_fit(file.path, @max_dimension) do
      {:ok, new_path} ->
        {:ok, %Waffle.File{file | path: new_path, is_tempfile?: true}}

      {:error, reason} ->
        {:error, "Failed to resize image: #{inspect(reason)}"}
    end
  end

  def filename(:avatar, _), do: "avatar"

  # As with `Kjogvi.Images.Uploader`, match plain fields rather than the
  # `%UserProfile{}` / `%User{}` structs to avoid a compile-time cycle. The
  # scope is the profile with its user loaded; the path is scoped by the
  # user's opaque token only — one avatar per user.
  def storage_dir(_version, {_file, %{user: %{public_token: user_token}}})
      when is_binary(user_token) do
    "uploads/avatars/#{user_token}"
  end

  # Fallback storage dir (e.g. in tests that pass an explicit scope).
  def storage_dir(_version, {_file, %{storage_dir: dir}}) do
    dir
  end

  def storage_dir(_version, _), do: "uploads/avatars"
end
