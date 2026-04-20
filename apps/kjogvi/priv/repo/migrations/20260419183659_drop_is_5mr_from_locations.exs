defmodule Kjogvi.Repo.Migrations.DropIs5mrFromLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      remove :is_5mr, :boolean, default: false, null: false
    end
  end
end
