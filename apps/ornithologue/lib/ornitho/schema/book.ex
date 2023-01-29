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

  schema "books" do
    field(:slug, :string)
    field(:version, :string)
    field(:name, :string)
    field(:description, :string)
    field(:extras, :map)

    has_many(:taxa, Ornitho.Schema.Taxon)

    timestamps()
  end
end
