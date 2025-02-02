defmodule Kjogvi.Repo.Migrations.AddHiddenToObservations do
  use Ecto.Migration

  def change do
    alter table("observations") do
      add :hidden, :boolean, null: false, default: false
    end
  end
end
