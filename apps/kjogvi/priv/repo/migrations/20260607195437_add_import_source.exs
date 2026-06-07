defmodule Kjogvi.Repo.Migrations.AddImportSource do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :import_source, :string
    end

    alter table(:observations) do
      add :import_source, :string
    end

    alter table(:locations) do
      add :import_source, :string
    end

    alter table(:images) do
      add :import_source, :string
    end
  end
end
