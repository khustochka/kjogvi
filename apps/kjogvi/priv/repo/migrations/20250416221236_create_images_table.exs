defmodule Kjogvi.Repo.Migrations.CreateImagesTable do
  use Ecto.Migration

  def change do
    create table(:images) do
      add :slug, :string, null: false
      add :user_id, references(:users, on_delete: :restrict), null: false
      add :photo, :string
      add :status, :string
      add :extras, :map, default: "{}"

      timestamps(type: :utc_datetime_usec)
    end

    create index(:images, [:user_id, :slug], unique: true)
  end
end
