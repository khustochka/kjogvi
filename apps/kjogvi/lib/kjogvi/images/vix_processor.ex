defmodule Kjogvi.Images.VixProcessor do
  @moduledoc """
  Image processing with libvips via Vix: resizing and metadata extraction.
  """

  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  @jpeg_save_opts [
    Q: 85,
    strip: true,
    optimize_coding: true
  ]

  @doc """
  Resize an image to at most `max_width` (never upscaling), preserving aspect
  ratio, and write it as JPEG to a temporary file. Returns `{:ok, path}`.
  """
  def resize_to_jpeg(input_path, max_width) do
    output_path = Waffle.File.generate_temporary_path(".jpg")

    with {:ok, image} <- VipsImage.new_from_file(input_path),
         width = VipsImage.width(image),
         scale = min(1.0, max_width / width),
         {:ok, resized} <- Operation.resize(image, scale),
         :ok <- VipsImage.write_to_file(resized, output_path, @jpeg_save_opts) do
      {:ok, output_path}
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
