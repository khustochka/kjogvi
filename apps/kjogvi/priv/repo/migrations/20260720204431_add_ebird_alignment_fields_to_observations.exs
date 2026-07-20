defmodule Kjogvi.Repo.Migrations.AddEbirdAlignmentFieldsToObservations do
  use Ecto.Migration

  def change do
    alter table(:observations) do
      add :breeding_code, :string
      add :ml_catalog_numbers, {:array, :string}, null: false, default: []
    end
  end
end
