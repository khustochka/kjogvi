defmodule Kjogvi.Repo.Migrations.CreateEbirdLocations do
  use Ecto.Migration

  def change do
    create table(:ebird_locations) do
      add :code, :string, null: false
      add :location_type, :string, null: false
      add :country_code, :string
      add :subnational1_code, :string
      add :subnational2_code, :string
      add :local_abbrev, :string
      add :name, :string
      add :name_long, :string
      add :name_short, :string
      add :nice_name, :string

      add :location_id, references(:locations, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:ebird_locations, [:code])
    create unique_index(:ebird_locations, [:location_id])
    create index(:ebird_locations, [:country_code])
    create index(:ebird_locations, [:subnational1_code])
  end
end
