defmodule Kjogvi.Repo.Migrations.ChangeCardsResolvedDefaultToTrue do
  use Ecto.Migration

  def up do
    alter table(:cards) do
      modify :resolved, :boolean, default: true, null: false
    end
  end

  def down do
    alter table(:cards) do
      modify :resolved, :boolean, default: false, null: false
    end
  end
end
