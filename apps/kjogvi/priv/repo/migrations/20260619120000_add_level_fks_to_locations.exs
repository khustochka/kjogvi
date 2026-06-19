defmodule Kjogvi.Repo.Migrations.AddLevelFksToLocations do
  use Ecto.Migration

  # No `section_id`: `section` is the lowest level and never an ancestor.
  @level_columns ~w(country_id subdivision1_id subdivision2_id city_id site_id)a

  def change do
    alter table(:locations) do
      for column <- @level_columns do
        add column, references("locations", on_delete: :restrict)
      end
    end

    for column <- @level_columns do
      create index(:locations, [column])
    end
  end
end
