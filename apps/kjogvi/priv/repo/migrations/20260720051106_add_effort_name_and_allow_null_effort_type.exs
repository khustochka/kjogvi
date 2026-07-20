defmodule Kjogvi.Repo.Migrations.AddEffortNameAndAllowNullEffortType do
  use Ecto.Migration

  def change do
    alter table(:checklists) do
      modify :effort_type, :string, null: true, from: {:string, null: false}
      add :effort_name, :text
    end
  end
end
