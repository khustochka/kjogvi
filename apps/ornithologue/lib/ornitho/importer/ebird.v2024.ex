defmodule Ornitho.Importer.Ebird.V2024 do
  @moduledoc """
  Importer for eBird/Clements checklist version 2024.
  """

  use Ornitho.Importer,
    slug: "ebird",
    version: "v2024",
    name: "eBird/Clements Checklist v2024",
    description:
      "Clements, J. F., P. C. Rasmussen, T. S. Schulenberg, M. J. Iliff, T. A. Fredericks, " <>
        "J. A. Gerbracht, D. Lepage, A. Spencer, S. M. Billerman, B. L. Sullivan, M. Smith, " <>
        "and C. L. Wood. 2024. The eBird/Clements checklist of Birds of the World: v2024. " <>
        "Downloaded from https://www.birds.cornell.edu/clementschecklist/download/",
    publication_date: ~D[2024-10-22]

  use Ornitho.StreamImporter,
    file_path: "import/ebird/v2024/ornithologue_ebird_v2024.csv"

  @impl Ornitho.StreamImporter
  def to_taxon_attrs(book, row, time) do
    {:ok, extras} = Jason.decode(row["extras"])

    %{
      book_id: book.id,
      name_sci: row["name_sci"],
      name_en: row["name_en"],
      code: row["code"],
      taxon_concept_id: row["taxon_concept_id"],
      category: row["category"],
      authority: row["authority"],
      authority_brackets: str_to_bool(row["authority_brackets"]),
      protonym: row["protonym"],
      order: row["order"],
      family: row["family"],
      sort_order: String.to_integer(row["sort_order"]),
      inserted_at: time,
      updated_at: time,
      extras: extras
    }
  end
end
