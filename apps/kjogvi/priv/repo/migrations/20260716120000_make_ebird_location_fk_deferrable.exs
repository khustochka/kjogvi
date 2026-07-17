defmodule Kjogvi.Repo.Migrations.MakeEbirdLocationFkDeferrable do
  use Ecto.Migration

  # The legacy import renumbers ISO `country`/`subdivision1` rows to their legacy
  # ids in place; `ebird_locations.location_id` may point at those rows, so it
  # needs the same commit-time deferral as the location level FKs (see
  # MakeLocationLevelFksDeferrable). INITIALLY IMMEDIATE keeps normal app
  # behaviour unchanged — only the import opts into deferral.
  def up do
    execute """
    ALTER TABLE ebird_locations
    ALTER CONSTRAINT ebird_locations_location_id_fkey DEFERRABLE INITIALLY IMMEDIATE
    """
  end

  def down do
    execute """
    ALTER TABLE ebird_locations
    ALTER CONSTRAINT ebird_locations_location_id_fkey NOT DEFERRABLE
    """
  end
end
