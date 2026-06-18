defmodule Kjogvi.Repo.Migrations.AddExtrasToLocations do
  use Ecto.Migration

  def change do
    alter table(:locations) do
      add :extras, :map, default: %{}, null: false
    end
  end
end
