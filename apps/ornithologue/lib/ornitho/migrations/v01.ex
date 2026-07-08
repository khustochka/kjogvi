defmodule Ornitho.Migrations.V01 do
  @moduledoc false

  use Ecto.Migration

  def up(opts \\ %{}) do
    prefix = opts[:prefix]

    create table(:ornitho_migrations, prefix: prefix) do
      add :version, :string, null: false, size: 16
    end

    # BOOKS
    create table(:books, prefix: prefix) do
      add :slug, :string, null: false, size: 16
      add :version, :string, null: false, size: 16
      add :importer, :string, null: false
      add :name, :string, null: false, size: 256
      add :description, :text
      add :publication_date, :date, null: false
      add :extras, :map, default: "{}"
      add :taxa_count, :integer
      add :imported_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:books, [:slug, :version], unique: true, prefix: prefix)

    # TAXA

    create table(:taxa, prefix: prefix) do
      add :book_id, references("books", on_delete: :delete_all, prefix: prefix), null: false
      add :name_sci, :string, size: 256, null: false
      add :name_en, :string
      add :code, :string, size: 256, null: false
      add :codes, {:array, :string}, null: false, default: []
      add :taxon_concept_id, :string, size: 256
      add :category, :string, size: 32
      add :authority, :string
      add :authority_brackets, :boolean
      # not present in eBird
      add :protonym, :string
      add :order, :string
      add :family, :string
      add :parent_species_id, references("taxa", on_delete: :nilify_all, prefix: prefix)
      # family_en, species_group, extinct, extinct_year, changes, range, ebird_order_num_str
      add :extras, :map, default: "{}"
      add :sort_order, :integer, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:taxa, [:book_id], unique: false, prefix: prefix)
    create index(:taxa, [:book_id, :name_sci], unique: true, prefix: prefix)
    create index(:taxa, [:book_id, :code], unique: true, prefix: prefix)
    create index(:taxa, [:book_id, :sort_order], unique: true, prefix: prefix)
    create index(:taxa, [:book_id, :taxon_concept_id], unique: true, prefix: prefix)

    # GIN index so `codes @> ARRAY[...]` / `codes && ARRAY[...]` lookups are index-backed.
    create index(:taxa, [:codes], using: "GIN", prefix: prefix)

    create index(:taxa, [:parent_species_id],
             unique: false,
             where: "parent_species_id IS NOT NULL",
             prefix: prefix
           )
  end

  def down(opts \\ %{}) do
    prefix = opts[:prefix]

    drop table(:taxa, prefix: prefix)
    drop table(:books, prefix: prefix)
    drop table(:ornitho_migrations, prefix: prefix)
  end
end
