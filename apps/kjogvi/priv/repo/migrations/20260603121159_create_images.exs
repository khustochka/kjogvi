defmodule Kjogvi.Repo.Migrations.CreateImages do
  use Ecto.Migration

  def change do
    create table(:images) do
      # Opaque, stable identifier used in storage paths (survives slug changes).
      add :token, :string, null: false
      add :slug, :string, null: false
      add :title, :string
      add :description, :text
      add :sort_order, :integer, null: false, default: 100
      # Holds derived metadata (dimensions, EXIF date); not user-editable.
      add :extras, :map, null: false, default: %{}
      # Waffle persists the file name as a single string.
      add :file, :string
      # Storage backend the file was uploaded with (e.g. "local", "s3_prod"),
      # so URLs resolve regardless of the running environment's default.
      add :storage_backend, :string, null: false, default: "local"

      add :user_id, references(:users, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:images, [:user_id, :slug])
    create unique_index(:images, [:token])

    create table(:image_observations) do
      add :image_id, references(:images, on_delete: :delete_all), null: false
      add :observation_id, references(:observations, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:image_observations, [:image_id, :observation_id])
    create index(:image_observations, [:observation_id])
  end
end
