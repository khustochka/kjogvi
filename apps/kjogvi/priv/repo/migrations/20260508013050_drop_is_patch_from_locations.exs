defmodule Kjogvi.Repo.Migrations.DropIsPatchFromLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      remove :is_patch, :boolean, default: false, null: false
    end
  end
end
