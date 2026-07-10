defmodule Kjogvi.Accounts.AvatarTest do
  use Kjogvi.DataCase, async: true

  import Kjogvi.AccountsFixtures

  alias Kjogvi.Accounts
  alias Kjogvi.Accounts.Avatar
  alias Kjogvi.Accounts.UserProfile

  @sample_image Path.expand(
                  Path.join([__DIR__, "../..", "support", "fixtures", "files", "sample_bird.jpg"])
                )

  setup do
    user = user_fixture()

    on_exit(fn ->
      avatar_dir =
        Path.join([
          Application.get_env(:waffle, :storage_dir_prefix, ""),
          "uploads/avatars",
          user.public_token
        ])

      File.rm_rf!(avatar_dir)
    end)

    %{user: user}
  end

  describe "update/2" do
    test "creates the profile row and stores the avatar on first save", %{user: user} do
      refute Repo.get_by(UserProfile, user_id: user.id)

      assert {:ok, profile} = Avatar.update(user, avatar_upload())
      assert profile.id
      assert profile.avatar
      assert profile.avatar_storage_backend == "local"
      assert File.exists?(stored_avatar_path(user))
    end

    test "stores a fixed file name regardless of the uploaded name", %{user: user} do
      {:ok, _} = Avatar.update(user, avatar_upload("IMG_1234.JPEG"))

      assert File.exists?(stored_avatar_path(user))
    end

    test "keeps existing profile fields when saving the avatar", %{user: user} do
      {:ok, _} =
        Accounts.update_user_profile_settings(user, %{"profile" => %{"about" => "Birder."}})

      assert {:ok, profile} = Avatar.update(user, avatar_upload())
      assert profile.about == "Birder."
      # get_by! raises on more than one row, so this also asserts no duplicate.
      assert Repo.get_by!(UserProfile, user_id: user.id).avatar
    end
  end

  describe "remove/1" do
    test "clears the avatar and deletes the file", %{user: user} do
      {:ok, _} = Avatar.update(user, avatar_upload())
      path = stored_avatar_path(user)
      assert File.exists?(path)

      assert {:ok, profile} = Avatar.remove(user)
      assert profile.avatar == nil
      assert profile.avatar_storage_backend == nil
      refute File.exists?(path)
    end

    test "without a profile row is a no-op", %{user: user} do
      assert {:ok, _} = Avatar.remove(user)
      refute Repo.get_by(UserProfile, user_id: user.id)
    end
  end

  defp avatar_upload(name \\ "me.jpg") do
    dest = Waffle.File.generate_temporary_path(".jpg")
    File.cp!(@sample_image, dest)
    %Plug.Upload{path: dest, filename: name, content_type: "image/jpeg"}
  end

  defp stored_avatar_path(user) do
    Path.join([
      Application.get_env(:waffle, :storage_dir_prefix, ""),
      "uploads/avatars",
      user.public_token,
      "avatar.jpg"
    ])
  end
end
