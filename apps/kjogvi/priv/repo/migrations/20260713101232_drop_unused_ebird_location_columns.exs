defmodule Kjogvi.Repo.Migrations.DropUnusedEbirdLocationColumns do
  use Ecto.Migration

  def change do
    alter table(:ebird_locations) do
      remove :local_abbrev, :string
      remove :name_long, :string
      remove :name_short, :string
      remove :nice_name, :string
    end
  end
end
