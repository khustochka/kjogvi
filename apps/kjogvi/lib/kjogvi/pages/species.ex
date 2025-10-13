defmodule Kjogvi.Pages.Species do
  @moduledoc """
  Species Page schema.
  """

  use Kjogvi.Schema

  import Ecto.Query
  import Ecto.Changeset

  alias Ornitho.Schema.Taxon
  alias Kjogvi.Pages.Species
  alias Kjogvi.Pages.SpeciesTaxaMapping
  alias Kjogvi.Repo

  schema "species_pages" do
    field(:name_en, :string)
    field(:name_sci, :string)
    field(:order, :string)
    field(:family, :string)
    field(:extras, :map)
    field(:sort_order, :integer)

    has_many :species_taxa_mappings, SpeciesTaxaMapping, foreign_key: :species_page_id

    timestamps()
  end

  def changeset(card, attrs) do
    card
    |> cast(attrs, [
      :name_en,
      :name_sci,
      :order,
      :family,
      :extras,
      :sort_order
    ])
    |> validate_required([
      :name_sci,
      :sort_order
    ])
  end

  def from_slug(slug) do
    name_sci = String.replace(slug, "_", " ", global: false)

    from(species in Species, where: species.name_sci == ^name_sci)
    |> Repo.one()
  end

  def from_taxon(nil) do
    nil
  end

  def from_taxon(taxon) do
    taxon
    |> Taxon.key()
    |> from_taxon_key()
  end

  def from_taxon_key(taxon_key) do
    query =
      from species in Species,
        join: species_taxa_mapping in assoc(species, :species_taxa_mappings),
        where: species_taxa_mapping.taxon_key == ^taxon_key

    query
    |> Repo.one()
  end
end
