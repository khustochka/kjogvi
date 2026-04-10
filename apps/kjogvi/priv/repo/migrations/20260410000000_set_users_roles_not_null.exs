defmodule Kjogvi.Repo.Migrations.SetUsersRolesNotNull do
  use Ecto.Migration

  def change do
    alter table(:users) do
      modify :roles, {:array, :string}, default: [], null: false, from: {:array, :string}
    end
  end
end
