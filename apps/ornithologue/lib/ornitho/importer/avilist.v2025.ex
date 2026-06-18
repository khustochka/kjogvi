defmodule Ornitho.Importer.AviList.V2025 do
  @moduledoc """
  Importer for AviList checklist version 2025.
  """

  use Ornitho.Importer,
    slug: "avilist",
    version: "v2025",
    name: "AviList v2025",
    description: """
    AviList Core Team. 2025. AviList: The Global Avian Checklist, v2025.
    https://doi.org/10.2173/avilist.v2025
    """,
    publication_date: ~D[2025-06-11]

  use Ornitho.StreamImporter,
    file_path: "import/avilist/v2025/ornithologue_avilist_v2025.csv"

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
