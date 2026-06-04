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
end
