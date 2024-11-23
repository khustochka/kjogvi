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

  def create_taxa_from_stream(book, stream) do
    stream
    |> CSV.decode(headers: true)
    |> Enum.reduce({0, %{}}, fn {:ok, row}, {num_saved, species_cache} ->
      {:ok, extras} = Jason.decode(row["extras"])

      attrs =
        row
        |> Map.put("parent_species_id", species_cache[row["parent_species_code"]])
        |> Map.put("extras", extras)

      taxon = Ops.Taxon.create!(book, attrs)

      new_cache =
        row["category"]
        |> case do
          "species" ->
            Map.put(species_cache, row["code"], taxon.id)

          _ ->
            species_cache
        end

      {num_saved + 1, new_cache}
    end)
    |> case do
      {n, _} -> {:ok, n}
    end
  end
end
