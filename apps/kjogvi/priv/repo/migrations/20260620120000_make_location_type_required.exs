defmodule Kjogvi.Repo.Migrations.MakeLocationTypeRequired do
  use Ecto.Migration

  def up do
    alter table(:locations) do
      modify :location_type, :string, size: 32, null: false
    end

    # With the column now NOT NULL the partial predicate is always true, so
    # replace the partial index with a plain one.
    drop index(:locations, :location_type, where: "location_type IS NOT NULL")
    create index(:locations, :location_type)
  end

  def down do
    drop index(:locations, :location_type)
    create index(:locations, :location_type, where: "location_type IS NOT NULL")

    alter table(:locations) do
      modify :location_type, :string, size: 32, null: true
    end
  end
end
