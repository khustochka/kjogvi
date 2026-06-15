defmodule Kjogvi.Repo.Migrations.AddEbirdCompleteToCard do
  use Ecto.Migration

  def change do
    alter table(:cards) do
      add :ebird_complete, :boolean, default: nil
    end
  end
end
