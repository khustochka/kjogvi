defmodule Ornitho.Importer.Ebird.V2023 do
  @moduledoc """
  Importer for eBird/Clements checklist version 2023.
  """

  use Ornitho.Importer,
    slug: "ebird",
    version: "v2023",
    name: "eBird/Clements Checklist v2023",
    description:
      "Clements, J. F., P. C. Rasmussen, T. S. Schulenberg, M. J. Iliff, T. A. Fredericks, " <>
        "J. A. Gerbracht, D. Lepage, A. Spencer, S. M. Billerman, B. L. Sullivan, " <>
        "and C. L. Wood. 2023. The eBird/Clements checklist of Birds of the World: v2023.\n" <>
        "Downloaded from https://www.birds.cornell.edu/clementschecklist/download/"

  @prepared_taxonomy_file "priv/import/ebird/v2023/ornithologue_ebird_v2023.csv"

  def create_taxa(book) do
    create_taxa_from_csv(book, @prepared_taxonomy_file)
  end

  def create_taxa_from_csv(book, csv_file) do
    csv_file
    |> File.stream!([:trim_bom])
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
