defmodule Kjogvi.Images.UploaderTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Images.Uploader

  describe "validate/1" do
    test "accepts known image extensions, case-insensitively" do
      for name <- ~w(photo.jpg photo.JPEG bird.png shot.webp scan.tiff x.tif p.heic q.heif) do
        assert Uploader.validate({%{file_name: name}, %{}}) == :ok
      end
    end

    test "rejects non-image extensions" do
      for name <- ~w(notes.txt archive.zip movie.mp4 noext) do
        assert {:error, _} = Uploader.validate({%{file_name: name}, %{}})
      end
    end
  end

  describe "filename/2" do
    test "names the original after the uploaded basename, without a version" do
      assert Uploader.filename(:original, {%{file_name: "pileated.jpg"}, %{}}) == "pileated"
    end

    test "suffixes variants with the version after the basename" do
      file = %{file_name: "pileated.jpg"}
      assert Uploader.filename(:medium, {file, %{}}) == "pileated_medium"
      assert Uploader.filename(:thumbnail, {file, %{}}) == "pileated_thumbnail"
    end

    test "ignores the scope's slug, so a later rename leaves filenames frozen" do
      file = %{file_name: "pileated.jpg"}
      # Even with a different live slug, the name derives from the upload.
      assert Uploader.filename(:medium, {file, %{slug: "renamed-later"}}) == "pileated_medium"
    end
  end

  describe "s3_object_headers/2" do
    test "sets an inline, long-lived cache regardless of version" do
      headers = Uploader.s3_object_headers(:medium, {%{file_name: "pileated.jpg"}, %{}})

      assert headers[:content_disposition] == "inline"
      assert headers[:cache_control] =~ "max-age=31536000"
      assert headers[:cache_control] =~ "immutable"
    end

    test "derives the original's content type from its extension" do
      assert content_type(:original, "shot.png") == "image/png"
      assert content_type(:original, "shot.webp") == "image/webp"
      assert content_type(:original, "shot.JPG") == "image/jpeg"
    end

    test "always reports JPEG for re-encoded variants" do
      for version <- ~w(thumbnail small medium large)a do
        # Even a PNG upload yields JPEG variants.
        assert content_type(version, "shot.png") == "image/jpeg"
      end
    end
  end

  defp content_type(version, file_name) do
    Uploader.s3_object_headers(version, {%{file_name: file_name}, %{}})[:content_type]
  end
end
