defmodule Kjogvi.Repo.Migrations.MakeLocationLevelFksDeferrable do
  use Ecto.Migration

  # The legacy import renumbers ISO `country`/`subdivision1` rows to their legacy
  # ids in place, which transiently breaks the level FKs of rows referencing the
  # old id. Making the level FKs DEFERRABLE lets the import defer the checks to
  # commit (`SET CONSTRAINTS ALL DEFERRED`). INITIALLY IMMEDIATE keeps normal
  # app behaviour unchanged — only the import opts into deferral.
  @level_columns ~w(country_id subdivision1_id subdivision2_id city_id site_id)a

  def up do
    for column <- @level_columns do
      execute """
      ALTER TABLE locations
      ALTER CONSTRAINT locations_#{column}_fkey DEFERRABLE INITIALLY IMMEDIATE
      """
    end
  end

  def down do
    for column <- @level_columns do
      execute """
      ALTER TABLE locations
      ALTER CONSTRAINT locations_#{column}_fkey NOT DEFERRABLE
      """
    end
  end
end
