defmodule Kjogvi.Repo.Migrations.CreateImportErrors do
  use Ecto.Migration

  def change do
    create table(:import_errors) do
      add :category, :string, null: false
      add :submission_id, :string
      add :rows, {:array, :map}, null: false, default: []
      add :error, :text

      add :import_log_id, references(:import_logs, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:import_errors, [:import_log_id])

    alter table(:import_logs) do
      add :upload_key, :string
    end
  end
end
