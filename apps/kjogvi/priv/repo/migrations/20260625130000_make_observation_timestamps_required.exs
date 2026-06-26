defmodule Kjogvi.Repo.Migrations.MakeObservationTimestampsRequired do
  use Ecto.Migration

  def up do
    alter table(:observations) do
      modify :inserted_at, :utc_datetime_usec, null: false
      modify :updated_at, :utc_datetime_usec, null: false
    end
  end

  def down do
    alter table(:observations) do
      modify :inserted_at, :utc_datetime_usec, null: true
      modify :updated_at, :utc_datetime_usec, null: true
    end
  end
end
