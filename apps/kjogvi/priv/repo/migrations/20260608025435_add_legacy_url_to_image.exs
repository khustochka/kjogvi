defmodule Kjogvi.Repo.Migrations.AddLegacyUrlToImage do
  use Ecto.Migration

  def change do
    alter table(:images) do
      add :legacy_url, :string
    end
  end
end
