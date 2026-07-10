defmodule Kjogvi.Images.VixProcessor do
  @moduledoc """
  Image processing with libvips via Vix: resizing and metadata extraction.
  """

  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  # Save options per output encoder. JPEG and WebP are lossy (quality 85); PNG
  # is lossless. Metadata is stripped from every variant.
  @jpeg_save_opts [Q: 85, strip: true, optimize_coding: true]
  @webp_save_opts [Q: 85, strip: true]
  @png_save_opts [strip: true]

  @doc """
  The extension (and therefore encoder) a resized variant gets for a given
  source extension.

  Web-friendly formats that every browser renders are preserved: PNG (which may
  carry transparency) and WebP. Everything else — JPEG, plus camera/archive
  formats browsers can't display such as HEIC/HEIF and TIFF — is flattened to
  JPEG. Used by both the resizer here and the uploader's variant naming so the
  two never disagree on a variant's format.
  """
  def variant_extension(source_extension) do
    case String.downcase(source_extension) do
      ".png" -> ".png"
      ".webp" -> ".webp"
      _ -> ".jpg"
    end
  end

  @doc """
  Resize an image to at most `max_width` (never upscaling), preserving aspect
  ratio, and write it to a temporary file. Returns `{:ok, path}`.

  The output format is chosen by `variant_extension/1` from `source_extension`
  (the original upload's extension): PNG and WebP keep their format, everything
  else is re-encoded as JPEG. The format is taken from `source_extension` rather
  than `input_path` because waffle may hand us a temp path whose extension does
  not reflect the original format.
  """
  def resize(input_path, max_width, source_extension) do
    ext = variant_extension(source_extension)
    output_path = Waffle.File.generate_temporary_path(ext)

    with {:ok, image} <- VipsImage.new_from_file(input_path),
         width = VipsImage.width(image),
         scale = min(1.0, max_width / width),
         {:ok, resized} <- Operation.resize(image, scale),
         :ok <- VipsImage.write_to_file(resized, output_path, save_opts(ext)) do
      {:ok, output_path}
    end
  end

  defp save_opts(".png"), do: @png_save_opts
  defp save_opts(".webp"), do: @webp_save_opts
  defp save_opts(_), do: @jpeg_save_opts

  @doc """
  Resize an image to fit within a `max_size`-square box (never upscaling),
  preserving aspect ratio, and write it as JPEG to a temporary file. Returns
  `{:ok, path}`.

  Unlike `resize/3`, the output is always JPEG regardless of the source
  format: transparency is flattened onto white. EXIF orientation is applied
  before the metadata is stripped.
  """
  def resize_to_fit(input_path, max_size) do
    output_path = Waffle.File.generate_temporary_path(".jpg")

    with {:ok, image} <-
           Operation.thumbnail(input_path, max_size, height: max_size, size: :VIPS_SIZE_DOWN),
         {:ok, flattened} <- flatten_alpha(image),
         :ok <- VipsImage.write_to_file(flattened, output_path, @jpeg_save_opts) do
      {:ok, output_path}
    end
  end

  # JPEG has no alpha channel; vips would flatten onto black, so flatten onto
  # white explicitly.
  defp flatten_alpha(image) do
    if VipsImage.has_alpha?(image) do
      Operation.flatten(image, background: [255.0, 255.0, 255.0])
    else
      {:ok, image}
    end
  end

  @doc """
  Extract image metadata: dimensions and EXIF capture date.

  Returns a map with `:width`, `:height`, and optionally `:exif_date` (a
  `"YYYY-MM-DD HH:MM:SS"` string, local camera time with no timezone) and
  `:exif_date_offset` (the corresponding UTC offset, e.g. `"+02:00"`, when the
  camera recorded one).
  """
  def extract_metadata(file_path) do
    with {:ok, image} <- VipsImage.new_from_file(file_path) do
      metadata =
        %{width: VipsImage.width(image), height: VipsImage.height(image)}
        |> maybe_put(:exif_date, extract_exif_date(image))
        |> maybe_put(:exif_date_offset, extract_exif_value(image, "exif-ifd2-OffsetTimeOriginal"))

      {:ok, metadata}
    end
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  # EXIF tags holding a capture timestamp, in priority order. libvips exposes
  # each tag as a named header field, so we read the specific tag rather than
  # scanning the raw EXIF blob (which would return whichever date appears first
  # in byte order, usually the file-modification time, not the capture time).
  @exif_date_fields [
    "exif-ifd2-DateTimeOriginal",
    "exif-ifd2-DateTimeDigitized",
    "exif-ifd0-DateTime"
  ]

  defp extract_exif_date(image) do
    Enum.find_value(@exif_date_fields, fn field ->
      parse_exif_date(extract_exif_value(image, field))
    end)
  end

  # libvips appends a type annotation to header values, e.g.
  # "2025:05:25 18:50:14 (..., ASCII, 20 components, ...)", so we strip
  # everything after the actual value.
  defp extract_exif_value(image, field) do
    case VipsImage.header_value_as_string(image, field) do
      {:ok, value} -> value |> String.split(" (", parts: 2) |> hd() |> String.trim()
      _ -> nil
    end
  end

  # EXIF stores dates as "YYYY:MM:DD HH:MM:SS"; normalize to a plain
  # "YYYY-MM-DD HH:MM:SS" string (local camera time, no timezone).
  defp parse_exif_date(value) when is_binary(value) do
    case Regex.run(~r/^(\d{4}):(\d{2}):(\d{2}) (\d{2}:\d{2}:\d{2})$/, value) do
      [_, year, month, day, time] -> "#{year}-#{month}-#{day} #{time}"
      _ -> nil
    end
  end

  defp parse_exif_date(_), do: nil
end
