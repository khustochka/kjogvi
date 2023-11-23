defmodule Ornitho.Repo.Migrations.AddTaxonConceptId do
  use Ecto.Migration

  def change do
    alter table("taxa") do
      add :taxon_concept_id, :string, size: 256
    end

    create index(:taxa, [:book_id, :taxon_concept_id], unique: true)
  end
end
