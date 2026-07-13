defmodule Kjogvi.Repo.Migrations.AddDisabledAndHideFlagToLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :disabled, :boolean, default: false, null: false
      add :hide_flag, :boolean, default: false, null: false
    end
  end
end
