defmodule Kjogvi.Repo.Migrations.CreateAdminSiteSettings do
  use Ecto.Migration

  def change do
    create table(:admin_site_settings) do
      add :key, :string, null: false
      add :value, :jsonb

      timestamps()
    end

    create unique_index(:admin_site_settings, [:key])
  end
end
