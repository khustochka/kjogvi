defmodule Kjogvi.Images.VixProcessorTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Images.VixProcessor
  alias Vix.Vips.Image, as: VipsImage
  alias Vix.Vips.Operation

  describe "resize_to_fit/2" do
    test "scales the longest side down to the maximum, preserving aspect ratio" do
      {:ok, path} = VixProcessor.resize_to_fit(generate_image(800, 1600), 512)

      assert dimensions(path) == {256, 512}
    end

    test "fits a landscape image by its width" do
      {:ok, path} = VixProcessor.resize_to_fit(generate_image(1600, 800), 512)

      assert dimensions(path) == {512, 256}
    end

    test "never upscales a smaller image" do
      {:ok, path} = VixProcessor.resize_to_fit(generate_image(60, 40), 512)

      assert dimensions(path) == {60, 40}
    end

    test "re-encodes the source as JPEG, flattening transparency" do
      {:ok, path} = VixProcessor.resize_to_fit(generate_image(700, 700, bands: 4), 512)

      assert Path.extname(path) == ".jpg"

      {:ok, out} = VipsImage.new_from_file(path)
      refute VipsImage.has_alpha?(out)
      assert VipsImage.width(out) == 512
    end
  end

  defp generate_image(width, height, opts \\ []) do
    {:ok, image} = Operation.black(width, height, bands: Keyword.get(opts, :bands, 3))
    path = Waffle.File.generate_temporary_path(".png")
    :ok = VipsImage.write_to_file(image, path)
    on_exit(fn -> File.rm(path) end)
    path
  end

  defp dimensions(path) do
    {:ok, image} = VipsImage.new_from_file(path)
    {VipsImage.width(image), VipsImage.height(image)}
  end
end
