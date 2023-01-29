defmodule Ornitho.Schema.Taxon do
  @moduledoc """
  This schema represents a taxon. This can be a species, a subspecies, or another taxonomic
  category. Subspecies and other sub-species taxa are linked to species, which makes them
  countable. Some books (e.g. eBird) contain uncountable taxa (slashes, spuhs. domestic forms).
  On the other hand, some lists may only contain species.

  Taxon is uniquely identified by a combination of book slug, book version, and taxon code.
  If there is no short code in the book, scientific name should be used as code.
  """
  use Ornitho.Schema

  schema "taxa" do
    field(:name_sci, :string)
    field(:name_en, :string)
    field(:code, :string)
    field(:category, :string)
    field(:authority, :string)
    field(:authority_brackets, :boolean)
    field(:protonym, :string)
    field(:order, :string)
    field(:family, :string)
    # Extras may include:
    # family_en, species_group, extinct, extinct_year, changes, range, ebird_order_num_str
    field(:extras, :map)
    field(:sort_order, :integer)

    belongs_to(:book, Ornitho.Schema.Book)
    belongs_to(:parent_species, Ornitho.Schema.Taxon)

    timestamps()
  end
end
