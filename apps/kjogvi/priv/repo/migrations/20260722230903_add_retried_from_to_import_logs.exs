defmodule Kjogvi.Repo.Migrations.AddRetriedFromToImportLogs do
  use Ecto.Migration

  def change do
    alter table(:import_logs) do
      add :retried_from_id, references(:import_logs, on_delete: :nilify_all)
    end

    create index(:import_logs, :retried_from_id)
  end
end
