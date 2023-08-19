defmodule Ornitho.Repo.Migrations.AddTaxaTable do
  use Ecto.Migration

  def change do
    create table(:taxa) do
      add :book_id, references("books", on_delete: :delete_all), null: false
      add :name_sci, :string, size: 256, null: false
      add :name_en, :string
      add :code, :string, size: 256, null: false
      add :category, :string, size: 32
      add :authority, :string
      add :authority_brackets, :boolean
      # not present in eBird
      add :protonym, :string
      add :order, :string
      add :family, :string
      add :parent_species_id, references("taxa", on_delete: :nilify_all)
      # family_en, species_group, extinct, extinct_year, changes, range, ebird_order_num_str
      add :extras, :map
      add :sort_order, :integer, null: false

      timestamps()
    end

    create index(:taxa, [:book_id], unique: false)
    create index(:taxa, [:book_id, :name_sci], unique: true)
    create index(:taxa, [:book_id, :code], unique: true)
    create index(:taxa, [:book_id, :sort_order], unique: true)

    create index(:taxa, [:parent_species_id],
             unique: false,
             where: "parent_species_id IS NOT NULL"
           )
  end
end
