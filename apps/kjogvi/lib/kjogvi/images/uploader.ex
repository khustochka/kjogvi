defmodule Kjogvi.Images.Uploader do
  @moduledoc """
  Waffle uploader for bird images.

  Stores the original unchanged plus four resized JPEG variants (quality 85,
  metadata stripped). Variants are produced with libvips via
  `Kjogvi.Images.VixProcessor`.
  """

  use Waffle.Definition
  use Waffle.Ecto.Definition

  @versions [:original, :large, :medium, :small, :thumbnail]

  @version_widths %{
    thumbnail: 640,
    small: 900,
    medium: 1200,
    large: 2400
  }

  @accepted_extensions ~w(.jpg .jpeg .png .webp .tiff .tif .heic .heif)

  # Storage keys are immutable for a given image (token folders + a frozen
  # basename), so objects can be cached for a year. A re-upload bumps waffle's
  # URL timestamp, which busts the cache despite the stable key.
  @cache_control "public, max-age=31536000, immutable"

  # Images are served via public, unsigned URLs, so stored objects must be
  # world-readable. Applies to S3; ignored by local storage.
  def acl(_version, _scope), do: :public_read

  # Headers stored on the S3 object (ignored by local storage):
  #
  #   * content_type — waffle does not set one, so S3 would default to
  #     application/octet-stream and browsers would download rather than
  #     render. Derive it from the stored filename's extension.
  #   * cache_control — see @cache_control.
  #   * content_disposition — render in the page rather than prompting a save.
  def s3_object_headers(version, {file, scope}) do
    name = "#{filename(version, {file, scope})}#{extension(version, {file, scope})}"

    [
      content_type: MIME.from_path(name),
      cache_control: @cache_control,
      content_disposition: "inline"
    ]
  end

  def validate({file, _scope}) do
    ext = file.file_name |> Path.extname() |> String.downcase()

    if ext in @accepted_extensions do
      :ok
    else
      {:error, "Invalid file type. Only images are accepted."}
    end
  end

  # The original is stored as-is.
  def transform(:original, _), do: :noaction

  def transform(version, _) when version in [:thumbnail, :small, :medium, :large] do
    width = @version_widths[version]

    fn _version, %Waffle.File{} = file ->
      case Kjogvi.Images.VixProcessor.resize_to_jpeg(file.path, width) do
        {:ok, new_path} ->
          {:ok, %Waffle.File{file | path: new_path, is_tempfile?: true}}

        {:error, reason} ->
          {:error, "Failed to resize image: #{inspect(reason)}"}
      end
    end
  end

  # Match on plain fields rather than the %Image{} / %User{} structs: this keeps
  # the uploader from depending on those modules, which would form a compile-time
  # cycle (Image -> Uploader.Type via `field :file`, Uploader -> Image).
  #
  # The path is scoped by the user's and the image's opaque tokens, so it
  # neither exposes the numeric user id nor depends on the slug (which can
  # change): uploads/images/<user_token>/<image_token>/.
  def storage_dir(_version, {_file, %{token: image_token, user: %{public_token: user_token}}})
      when is_binary(user_token) and is_binary(image_token) do
    "uploads/images/#{user_token}/#{image_token}"
  end

  # Fallback storage dir (e.g. in tests that pass an explicit scope).
  def storage_dir(_version, {_file, %{storage_dir: dir}}) do
    dir
  end

  def storage_dir(_version, _), do: "uploads/images"

  # Files are named after the original basename, which waffle freezes into the
  # `file` column at upload time and replays on every URL build. We deliberately
  # do NOT read the slug here: the slug can change, but the stored basename must
  # not, or computed URLs would point at files that no longer exist. Uploading
  # as `<slug>.jpg` therefore yields `<slug>.jpg` and `<slug>_<version>.jpg`,
  # frozen regardless of any later rename.
  def filename(:original, {file, _scope}) do
    Path.basename(file.file_name, Path.extname(file.file_name))
  end

  def filename(version, {file, _scope}) do
    base = Path.basename(file.file_name, Path.extname(file.file_name))
    "#{base}_#{version}"
  end

  # The original keeps its extension; variants are always JPEG.
  def extension(:original, {file, _scope}) do
    file.file_name |> Path.extname() |> String.downcase()
  end

  def extension(_version, _), do: ".jpg"
end
