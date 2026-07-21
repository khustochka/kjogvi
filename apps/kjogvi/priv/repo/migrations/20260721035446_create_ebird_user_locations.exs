defmodule Kjogvi.Repo.Migrations.CreateEbirdUserLocations do
  use Ecto.Migration

  def change do
    create table(:ebird_user_locations) do
      add :ebird_loc_id, :string, null: false
      add :name, :string, null: false
      add :state, :string
      add :county, :string
      add :lat, :decimal
      add :lon, :decimal

      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :location_id, references(:locations, on_delete: :nilify_all)

      timestamps()
    end

    create unique_index(:ebird_user_locations, [:user_id, :ebird_loc_id])
    create index(:ebird_user_locations, [:location_id])
  end
end
