defmodule Kjogvi.Images.AvatarUploaderTest do
  use ExUnit.Case, async: true

  alias Kjogvi.Images.AvatarUploader

  describe "validate/1" do
    test "accepts known image extensions, case-insensitively" do
      for name <- ~w(photo.jpg photo.JPEG bird.png shot.webp scan.tiff x.tif p.heic q.heif) do
        assert AvatarUploader.validate({%{file_name: name}, %{}}) == :ok
      end
    end

    test "rejects non-image extensions" do
      for name <- ~w(notes.txt archive.zip movie.mp4 noext) do
        assert {:error, _} = AvatarUploader.validate({%{file_name: name}, %{}})
      end
    end
  end

  describe "s3_key/2" do
    test "stores a fixed avatar.jpg under the user token, whatever the upload was called" do
      scope = %{user: %{public_token: "usertok"}}

      for name <- ~w(IMG_1234.HEIC me.png scan.tiff photo.jpg) do
        assert AvatarUploader.s3_key(:avatar, {%{file_name: name}, scope}) ==
                 "uploads/avatars/usertok/avatar.jpg"
      end
    end

    test "ignores any profile fields other than the user token" do
      scope = %{user: %{public_token: "usertok"}, about: "hi", id: 42}

      assert AvatarUploader.s3_key(:avatar, {%{file_name: "me.jpg"}, scope}) ==
               "uploads/avatars/usertok/avatar.jpg"
    end
  end

  describe "s3_object_headers/2" do
    test "serves an inline, long-cached JPEG" do
      headers = AvatarUploader.s3_object_headers(:avatar, {%{file_name: "me.png"}, %{}})

      assert headers[:content_type] == "image/jpeg"
      assert headers[:content_disposition] == "inline"
      assert headers[:cache_control] =~ "max-age=31536000"
    end
  end
end
