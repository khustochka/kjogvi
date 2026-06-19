defmodule Kjogvi.Repo.Migrations.AddUserToLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :user_id, references(:users, on_delete: :restrict)
    end

    create index(:locations, [:user_id])
  end
end
