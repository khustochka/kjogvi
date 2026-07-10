defmodule Kjogvi.Repo.Migrations.AddAvatarToUserProfiles do
  use Ecto.Migration

  def change do
    alter table(:user_profiles) do
      add :avatar, :string
      add :avatar_storage_backend, :string
    end
  end
end
