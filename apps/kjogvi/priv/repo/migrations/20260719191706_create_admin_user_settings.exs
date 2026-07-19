defmodule Kjogvi.Repo.Migrations.CreateAdminUserSettings do
  use Ecto.Migration

  def change do
    create table(:admin_user_settings) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :value, :jsonb

      timestamps()
    end

    create unique_index(:admin_user_settings, [:user_id, :key])
  end
end
