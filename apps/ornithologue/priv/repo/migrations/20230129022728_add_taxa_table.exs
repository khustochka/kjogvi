defmodule Ornitho.Repo.Migrations.AddTaxaTable do
  use Ecto.Migration

  def change do
    create table(:taxa) do
      add :book_id, references("books"), null: false
      add :name_sci, :string, size: 256, null: false
      add :name_en, :string
      add :code, :string, size: 256, null: false
      add :category, :string, size: 32
      add :authority, :string
      add :authority_brackets, :boolean
      add :protonym, :string # not present in eBird
      add :order, :string
      add :family, :string
      add :parent_species_id, references("taxa")
      add :extras, :map # family_en, species_group, extinct, extinct_year, changes, range, ebird_order_num_str
      add :sort_order, :integer, null: false

      timestamps()
    end

    create index(:taxa, [:book_id], unique: false)
    create index(:taxa, [:book_id, :name_sci], unique: true)
    create index(:taxa, [:book_id, :code], unique: true)
    # TODO: make sort_order mandatory
    create index(:taxa, [:book_id, :sort_order], unique: true, where: "sort_order IS NOT NULL")
    create index(:taxa, [:parent_species_id], unique: false, where: "parent_species_id IS NOT NULL")
  end
end
