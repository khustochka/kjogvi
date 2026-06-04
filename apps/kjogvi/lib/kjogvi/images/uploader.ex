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

  # Files are named after the slug as it was at upload time. The token folders
  # already guarantee uniqueness, so a later slug rename simply leaves the
  # filename as a (cosmetic) historical label.
  def filename(version, {_file, %{slug: slug}}) when is_binary(slug) do
    "#{slug}_#{version}"
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
