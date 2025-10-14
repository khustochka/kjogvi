defmodule Kjogvi.Repo.Migrations.CreateSpeciesPages do
  use Ecto.Migration

  def change do
    create table(:species_pages) do
      add :name_sci, :string, null: false
      # Name inherited from Taxonomy list, may be overwritten by name_en
      add :common_name, :string
      add :name_en, :string
      add :order, :string
      add :family, :string
      add :extras, :map, default: "{}"
      add :sort_order, :integer, null: false

      timestamps()
    end

    create index(:species_pages, [:name_sci])
    create index(:species_pages, [:sort_order])

    create table(:species_taxa_mappings) do
      add :species_page_id, references("species_pages", on_delete: :restrict), null: false
      add :taxon_key, :string, null: false

      timestamps()
    end

    create index(:species_taxa_mappings, [:species_page_id])
    create index(:species_taxa_mappings, [:taxon_key], unique: true)
  end
end
