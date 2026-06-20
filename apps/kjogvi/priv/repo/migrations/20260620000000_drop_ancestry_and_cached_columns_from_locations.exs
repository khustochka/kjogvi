defmodule Kjogvi.Repo.Migrations.DropAncestryAndCachedColumnsFromLocations do
  use Ecto.Migration

  # The arbitrary-depth `ancestry` array and the denormalized `cached_*`
  # columns are superseded by the level FK columns (`country_id … site_id`).
  # Nothing reads them anymore (see the location hierarchy redesign).

  def up do
    alter table(:locations) do
      remove :ancestry
      remove :cached_public_location_id
      remove :cached_country_id
      remove :cached_parent_id
      remove :cached_city_id
      remove :cached_subdivision_id
    end
  end

  def down do
    alter table(:locations) do
      add :ancestry, {:array, :bigint}
      add :cached_public_location_id, references(:locations, on_delete: :nilify_all)
      add :cached_country_id, references(:locations, on_delete: :restrict)
      add :cached_parent_id, references(:locations, on_delete: :nilify_all)
      add :cached_city_id, references(:locations, on_delete: :nilify_all)
      add :cached_subdivision_id, references(:locations, on_delete: :nilify_all)
    end

    create index(:locations, [:ancestry], using: :gin)

    create index(:locations, [:cached_country_id],
             where: "cached_country_id IS NOT NULL",
             name: :locations_cached_country_id_index
           )
  end
end
