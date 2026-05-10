defmodule Kjogvi.Repo.Migrations.RenameLogSettingsToLogbookSettings do
  use Ecto.Migration

  def up do
    execute """
    UPDATE users
    SET extras = (extras - 'log_settings') || jsonb_build_object('logbook_settings', extras->'log_settings')
    WHERE extras ? 'log_settings'
    """
  end

  def down do
    execute """
    UPDATE users
    SET extras = (extras - 'logbook_settings') || jsonb_build_object('log_settings', extras->'logbook_settings')
    WHERE extras ? 'logbook_settings'
    """
  end
end
