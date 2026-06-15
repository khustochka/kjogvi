defmodule Kjogvi.Repo.Migrations.RemoveIsMainUserFromUsers do
  use Ecto.Migration

  def up do
    drop index(:users, [:is_main_user], name: :users_is_main_user_index)

    alter table(:users) do
      remove :is_main_user
    end
  end

  def down do
    alter table(:users) do
      add :is_main_user, :boolean, null: false, default: false
    end

    create unique_index(:users, [:is_main_user],
             where: "is_main_user",
             name: :users_is_main_user_index
           )
  end
end
