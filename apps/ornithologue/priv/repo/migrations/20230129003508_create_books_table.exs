defmodule Ornitho.Repo.Migrations.CreateBooksTable do
  use Ecto.Migration

  def change do
    create table(:books) do
      add :slug, :string, null: false, size: 16
      add :version, :string, null: false, size: 16
      add :name, :string, null: false, size: 256
      add :description, :text
      add :extras, :map

      timestamps()
    end

    create index(:books, [:slug, :version], unique: true)
  end
end
