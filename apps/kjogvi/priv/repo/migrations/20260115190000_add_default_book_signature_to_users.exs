defmodule Kjogvi.Repo.Migrations.AddDefaultBookSignatureToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :default_book_signature, :string
    end

    create index(:users, [:default_book_signature])
  end
end
