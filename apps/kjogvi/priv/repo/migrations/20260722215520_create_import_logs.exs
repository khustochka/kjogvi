defmodule Kjogvi.Repo.Migrations.CreateImportLogs do
  use Ecto.Migration

  def change do
    create table(:import_logs) do
      add :source, :string, null: false
      add :status, :string, null: false, default: "queued"
      add :summary, :map, null: false, default: %{}
      add :error, :text
      add :started_at, :utc_datetime_usec
      add :finished_at, :utc_datetime_usec

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:import_logs, [:user_id])
  end
end
