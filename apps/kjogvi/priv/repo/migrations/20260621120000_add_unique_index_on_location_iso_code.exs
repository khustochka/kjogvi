defmodule Kjogvi.Repo.Migrations.AddUniqueIndexOnLocationIsoCode do
  use Ecto.Migration

  def change do
    # Only common ISO 3166 locations carry an iso_code; user locations leave it
    # null. A partial index keeps the codes unique while allowing many nulls.
    create unique_index(:locations, [:iso_code], where: "iso_code IS NOT NULL")
  end
end
