defmodule Kjogvi.Repo.Migrations.AddUserToCards do
  use Ecto.Migration

  def change do
    alter table("cards") do
      add :user_id, references(:users, on_delete: :restrict), null: false
    end
  end
end
