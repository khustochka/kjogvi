defmodule Kjogvi.Repo.Migrations.AddIsMainUserToUsers do
  use Ecto.Migration

  def up do
    alter table(:users) do
      add :is_main_user, :boolean, null: false, default: false
    end

    create unique_index(:users, [:is_main_user],
             where: "is_main_user",
             name: :users_is_main_user_index
           )

    execute """
    UPDATE users
    SET is_main_user = true
    WHERE id = (
      SELECT id
      FROM users
      WHERE 'admin' = ANY(roles)
      ORDER BY id ASC
      LIMIT 1
    )
    """
  end

  def down do
    drop index(:users, [:is_main_user], name: :users_is_main_user_index)

    alter table(:users) do
      remove :is_main_user
    end
  end
end
