defmodule Kjogvi.Repo.Migrations.SpecialLocations do
  use Ecto.Migration

  def change do
    create table(:special_locations) do
      add :parent_location_id, references("locations", on_delete: :delete_all), null: false
      add :child_location_id, references("locations", on_delete: :delete_all), null: false
    end

    create index(:special_locations, :parent_location_id)
  end
end
