defmodule Ornitho.Importer.Ebird.V2025 do
  @moduledoc """
  Importer for eBird/Clements checklist version 2025.
  """

  use Ornitho.Importer,
    slug: "ebird",
    version: "v2025",
    name: "eBird/Clements Checklist v2025",
    description: """
    Clements, J. F., P. C. Rasmussen, T. S. Schulenberg, M. J. Iliff, J. A. Gerbracht,
    D. Lepage, A. Spencer, S. M. Billerman, B. L. Sullivan, M. Smith, and C. L. Wood. 2025.
    The eBird/Clements checklist of Birds of the World: v2025.
    Downloaded from https://www.birds.cornell.edu/clementschecklist/download/
    """,
    publication_date: ~D[2025-10-31]

  use Ornitho.StreamImporter,
    file_path: "import/ebird/v2025/ornithologue_ebird_v2025.csv"

  import Ornitho.Util

  @impl Ornitho.StreamImporter
  def to_taxon_attrs(book, row, time) do
    {:ok, extras} = Jason.decode(row["extras"])

    %{
      book_id: book.id,
      name_sci: cast_string(row["name_sci"]),
      name_en: cast_string(row["name_en"]),
      code: cast_string(row["code"]),
      taxon_concept_id: cast_string(row["taxon_concept_id"]),
      category: cast_string(row["category"]),
      authority: cast_string(row["authority"]),
      authority_brackets: cast_boolean(row["authority_brackets"]),
      protonym: cast_string(row["protonym"]),
      order: cast_string(row["order"]),
      family: cast_string(row["family"]),
      sort_order: cast_integer(row["sort_order"]),
      inserted_at: time,
      updated_at: time,
      extras: extras
    }
  end
end
