defmodule Kjogvi.Repo.Migrations.CreateLocations do
  use Ecto.Migration

  def change do
    create table(:locations) do
      add :slug, :string, size: 64, null: false
      add :name_en, :string, size: 256, null: false
      add :location_type, :string, size: 32
      add :ancestry, {:array, :bigint}
      add :iso_code, :string, size: 3
      add :is_private, :boolean, default: false, null: false
      add :is_patch, :boolean, default: false, null: false
      add :is_5mr, :boolean, default: false, null: false
      add :lat, :numeric, scale: 5, precision: 8
      add :lon, :numeric, scale: 5, precision: 8
      add :public_index, :smallint
      add :cached_parent_id, references("locations", on_delete: :nilify_all)
      add :cached_city_id, references("locations", on_delete: :nilify_all)
      add :cached_subdivision_id, references("locations", on_delete: :nilify_all)
      add :cached_country_id, references("locations", on_delete: :nilify_all)

      timestamps()
    end

    create index(:locations, :slug, unique: true)
    create index(:locations, :ancestry, using: "GIN")
  end
end
