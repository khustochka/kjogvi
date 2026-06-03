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
end
