defmodule Kjogvi.Accounts.Avatar do
  @moduledoc """
  User avatar operations: replacing and removing the avatar stored on the
  user's profile.

  Kept apart from `Kjogvi.Accounts` so the accounts context does not depend on
  the image machinery (`Kjogvi.Images`), which itself depends on accounts
  schemas — the two would otherwise form a dependency cycle. Only the web
  layer calls this module.
  """

  alias Kjogvi.Accounts.User
  alias Kjogvi.Accounts.UserProfile
  alias Kjogvi.Images
  alias Kjogvi.Images.AvatarUploader
  alias Kjogvi.Repo

  @doc """
  Replaces the user's avatar with the uploaded file, creating the profile row
  on first save.

  The file is processed and written to storage during the update; a storage
  failure returns `{:error, :storage_failed}`.
  """
  def update(%User{} = user, upload) do
    attrs = %{
      "avatar" => upload,
      "avatar_storage_backend" => Images.current_storage_backend()
    }

    user
    |> get_or_build_profile()
    |> UserProfile.avatar_changeset(attrs)
    |> Repo.insert_or_update()
    |> case do
      {:ok, profile} ->
        {:ok, profile}

      {:error, %Ecto.Changeset{} = changeset} ->
        # :avatar is never validated for content, so an error on it can only
        # mean the storage write failed (waffle's Ecto type collapses store
        # failures into a cast error).
        if Keyword.has_key?(changeset.errors, :avatar) do
          {:error, :storage_failed}
        else
          {:error, changeset}
        end
    end
  end

  @doc """
  Removes the user's avatar, deleting the stored file.
  """
  def remove(%User{} = user) do
    profile = get_or_build_profile(user)

    if profile.avatar do
      AvatarUploader.delete({profile.avatar, profile})
    end

    if profile.id do
      profile
      |> Ecto.Changeset.change(avatar: nil, avatar_storage_backend: nil)
      |> Repo.update()
    else
      {:ok, profile}
    end
  end

  # The profile with its owning user set: the waffle scope for avatar storage
  # paths reads the user's public token off the profile.
  defp get_or_build_profile(%User{} = user) do
    profile = Repo.preload(user, :profile).profile || %UserProfile{user_id: user.id}
    %{profile | user: user}
  end
end
