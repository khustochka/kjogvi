defmodule Ornitho.Schema.Book do
  @moduledoc """
  This schema represents a "book" - a taxonomic list (checklist). A book is uniquely identified
  by a combination of slug and version.

  Potential improvements:
  * ordering column (to be able to find the previous version of the book). Now version can
    be used
  * date of the publication
  * authors, citations (now go in extras)
  * attributes like `only_species` (book that contains only species), `only_countable` etc
  """
  use Ornitho.Schema

  alias __MODULE__
  alias Ornitho.Schema.Taxon

  @default_order [asc: :slug, asc: :version]

  @type t() :: %__MODULE__{}

  schema "books" do
    field(:slug, :string)
    field(:version, :string)
    field(:name, :string)
    field(:description, :string)
    field(:extras, :map)
    # Time when the taxa were imported
    field(:imported_at, :utc_datetime_usec)

    has_many(:taxa, Taxon, preload_order: [asc: :sort_order])

    timestamps()

    field :taxa_count, :integer, virtual: true
  end

  def default_order do
    @default_order
  end

  def creation_changeset(%Book{} = book, attrs) do
    book
    |> changeset_common_process(attrs)
  end

  def updating_changeset(%Book{} = book, attrs \\ %{}) do
    book
    |> changeset_common_process(attrs)
  end

  defp changeset_common_process(%Book{} = book, attrs) do
    book
    |> Ecto.Changeset.cast(attrs, saveable_fields())
    |> Ecto.Changeset.validate_required([:slug, :version, :name])
    |> Ecto.Changeset.unique_constraint([:version, :slug], name: "books_slug_version_index")
  end

  defp saveable_fields do
    Book.__schema__(:fields) -- [:id, :inserted_at, :updated_at]
  end
end
