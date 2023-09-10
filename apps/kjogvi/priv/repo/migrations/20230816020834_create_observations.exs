defmodule Kjogvi.Repo.Migrations.CreateObservations do
  use Ecto.Migration

  def change do
    create table(:observations) do
      add :card_id, references("cards", on_delete: :restrict), null: false
      add :taxon_key, :string, null: false
      add :quantity, :string
      add :voice, :boolean, default: false, null: false
      add :notes, :text
      add :private_notes, :text
      add :unreported, :boolean, default: false, null: false
      add :ebird_obs_id, :string

      timestamps(null: true)
    end

    create index(:observations, [:card_id])
    create index(:observations, [:taxon_key])
  end
end
