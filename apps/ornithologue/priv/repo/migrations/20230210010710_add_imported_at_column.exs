defmodule Ornitho.Repo.Migrations.AddImportedAtColumn do
  use Ecto.Migration

  def change do
    alter table("books") do
      add :imported_at, :utc_datetime_usec
    end
  end
end
