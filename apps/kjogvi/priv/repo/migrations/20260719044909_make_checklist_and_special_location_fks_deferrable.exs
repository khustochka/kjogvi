defmodule Kjogvi.Repo.Migrations.MakeChecklistAndSpecialLocationFksDeferrable do
  use Ecto.Migration

  # The legacy import renumbers ISO `country`/`subdivision1` rows to their legacy
  # ids in place; `checklists.location_id` and `special_locations.child_location_id`
  # may point at those rows, so they need the same commit-time deferral as the
  # location level FKs (see MakeLocationLevelFksDeferrable and
  # MakeEbirdLocationFkDeferrable). INITIALLY IMMEDIATE keeps normal app
  # behaviour unchanged — only the import opts into deferral.
  def up do
    execute """
    ALTER TABLE checklists
    ALTER CONSTRAINT checklists_location_id_fkey DEFERRABLE INITIALLY IMMEDIATE
    """

    execute """
    ALTER TABLE special_locations
    ALTER CONSTRAINT special_locations_child_location_id_fkey DEFERRABLE INITIALLY IMMEDIATE
    """
  end

  def down do
    execute """
    ALTER TABLE checklists
    ALTER CONSTRAINT checklists_location_id_fkey NOT DEFERRABLE
    """

    execute """
    ALTER TABLE special_locations
    ALTER CONSTRAINT special_locations_child_location_id_fkey NOT DEFERRABLE
    """
  end
end
