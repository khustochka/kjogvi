defmodule Ornitho.Migrations.V01 do
  use Ecto.Migration

  def up do
    create table(:ornitho_migrations) do
      add :version, :string, null: false, size: 16
    end

    # BOOKS
    create table(:books) do
      add :slug, :string, null: false, size: 16
      add :version, :string, null: false, size: 16
      add :name, :string, null: false, size: 256
      add :description, :text
      add :extras, :map
      add :imported_at, :utc_datetime_usec

      timestamps()
    end

    create index(:books, [:slug, :version], unique: true)

    # TAXA

    create table(:taxa) do
      add :book_id, references("books", on_delete: :delete_all), null: false
      add :name_sci, :string, size: 256, null: false
      add :name_en, :string
      add :code, :string, size: 256, null: false
      add :taxon_concept_id, :string, size: 256
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
    create index(:taxa, [:book_id, :taxon_concept_id], unique: true)

    create index(:taxa, [:parent_species_id],
             unique: false,
             where: "parent_species_id IS NOT NULL"
           )
  end

  def down do
    drop table(:taxa)
    drop table(:books)
    drop table(:ornitho_migrations)
  end
end
