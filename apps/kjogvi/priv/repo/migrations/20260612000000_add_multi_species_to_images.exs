defmodule Kjogvi.Repo.Migrations.AddMultiSpeciesToImages do
  use Ecto.Migration

  def change do
    alter table(:images) do
      # Denormalized: true when more than one observation is attached. Kept in
      # sync whenever the image's observation set changes.
      add :multi_species, :boolean, null: false, default: false
    end
  end
end
