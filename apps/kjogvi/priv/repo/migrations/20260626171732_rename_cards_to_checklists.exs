defmodule Kjogvi.Repo.Migrations.RenameCardsToChecklists do
  use Ecto.Migration

  # Renames the `cards` table to `checklists` and the `observations.card_id`
  # column to `checklist_id`, along with every dependent constraint, index and
  # sequence. App code still maps the schemas onto the old names; that switch
  # happens in a later step.

  def up do
    rename table(:cards), to: table(:checklists)
    rename table(:observations), :card_id, to: :checklist_id

    execute "ALTER SEQUENCE cards_id_seq RENAME TO checklists_id_seq"

    execute "ALTER TABLE checklists RENAME CONSTRAINT cards_pkey TO checklists_pkey"

    execute "ALTER TABLE checklists RENAME CONSTRAINT cards_location_id_fkey TO checklists_location_id_fkey"

    execute "ALTER TABLE checklists RENAME CONSTRAINT cards_user_id_fkey TO checklists_user_id_fkey"

    execute "ALTER TABLE observations RENAME CONSTRAINT observations_card_id_fkey TO observations_checklist_id_fkey"

    # The pkey index is renamed implicitly by the RENAME CONSTRAINT above.
    execute "ALTER INDEX cards_cached_month_index RENAME TO checklists_cached_month_index"
    execute "ALTER INDEX cards_cached_year_index RENAME TO checklists_cached_year_index"
    execute "ALTER INDEX cards_ebird_id_index RENAME TO checklists_ebird_id_index"
    execute "ALTER INDEX cards_location_id_index RENAME TO checklists_location_id_index"

    execute "ALTER INDEX cards_observ_date_location_id_index RENAME TO checklists_observ_date_location_id_index"

    execute "ALTER INDEX cards_user_id_index RENAME TO checklists_user_id_index"
    execute "ALTER INDEX observations_card_id_index RENAME TO observations_checklist_id_index"
  end

  def down do
    execute "ALTER INDEX observations_checklist_id_index RENAME TO observations_card_id_index"
    execute "ALTER INDEX checklists_user_id_index RENAME TO cards_user_id_index"

    execute "ALTER INDEX checklists_observ_date_location_id_index RENAME TO cards_observ_date_location_id_index"

    execute "ALTER INDEX checklists_location_id_index RENAME TO cards_location_id_index"
    execute "ALTER INDEX checklists_ebird_id_index RENAME TO cards_ebird_id_index"
    execute "ALTER INDEX checklists_cached_year_index RENAME TO cards_cached_year_index"
    execute "ALTER INDEX checklists_cached_month_index RENAME TO cards_cached_month_index"

    execute "ALTER TABLE observations RENAME CONSTRAINT observations_checklist_id_fkey TO observations_card_id_fkey"

    execute "ALTER TABLE checklists RENAME CONSTRAINT checklists_user_id_fkey TO cards_user_id_fkey"

    execute "ALTER TABLE checklists RENAME CONSTRAINT checklists_location_id_fkey TO cards_location_id_fkey"

    execute "ALTER TABLE checklists RENAME CONSTRAINT checklists_pkey TO cards_pkey"

    execute "ALTER SEQUENCE checklists_id_seq RENAME TO cards_id_seq"

    rename table(:observations), :checklist_id, to: :card_id
    rename table(:checklists), to: table(:cards)
  end
end
