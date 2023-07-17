defmodule Ornitho.Schema.Taxon do
  @moduledoc """
  This schema represents a taxon. This can be a species, a subspecies, or another taxonomic
  category. Subspecies and other sub-species taxa are linked to species, which makes them
  countable. Some books (e.g. eBird) contain uncountable taxa (slashes, spuhs, domestic forms).
  On the other hand, some lists may only contain species.

  Taxon is uniquely identified by a combination of book slug, book version, and taxon code.
  If there is no short code in the book, scientific name may be used as code.
  """
  use Ornitho.Schema

  alias Ornitho.Schema.{Book, Taxon}

  @required_fields [:name_sci, :name_en, :code, :category, :sort_order, :book_id]
  @default_order [asc: :sort_order]

  @type t() :: %__MODULE__{}

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

    has_many(:child_taxa, Ornitho.Schema.Taxon, foreign_key: :parent_species_id, preload_order: @default_order)

    timestamps()
  end

  def default_order do
    @default_order
  end

  def formatted_authority(%Taxon{authority: nil}) do
    nil
  end

  def formatted_authority(%Taxon{authority: authority, authority_brackets: true}) do
    "(#{authority})"
  end

  def formatted_authority(%Taxon{authority: authority, authority_brackets: _}) do
    authority
  end

  def is_extinct?(%Taxon{extras: extras}) do
    extras["extinct"]
  end

  def creation_changeset(%Book{} = book, attrs) do
    book
    |> Ecto.build_assoc(:taxa)
    |> creation_changeset(attrs)
  end

  def creation_changeset(%Taxon{} = taxon, attrs) do
    taxon
    |> changeset_common_process(attrs, :create)
  end

  def updating_changeset(%Taxon{} = taxon, attrs \\ %{}) do
    taxon
    |> changeset_common_process(attrs, :update)
  end

  # TODO: sort order should be consequitive?
  # TODO: parent_species should point to a species
  defp changeset_common_process(%Taxon{} = taxon, attrs, action) do
    taxon
    |> Ecto.Changeset.cast(attrs, saveable_fields(action))
    |> Ecto.Changeset.validate_required(@required_fields)
    |> Ecto.Changeset.unique_constraint([:name_sci, :book_id],
      name: "taxa_book_id_name_sci_index"
    )
    |> Ecto.Changeset.unique_constraint([:code, :book_id], name: "taxa_book_id_code_index")
    |> Ecto.Changeset.unique_constraint([:sort_order, :book_id],
      name: "taxa_book_id_sort_order_index"
    )
  end

  defp saveable_fields(:create) do
    Taxon.__schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end

  defp saveable_fields(:update) do
    saveable_fields(:create) -- [:book_id]
  end
end
