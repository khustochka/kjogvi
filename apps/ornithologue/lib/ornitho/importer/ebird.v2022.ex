defmodule Ornitho.Importer.Ebird.V2022 do
  @moduledoc """
  Importer for eBird/Clements checklist version 2022.
  """

  @prepared_taxonomy_file "priv/import/ebird/v2022/ornithologue_ebird_v2022.csv"

  use Ornitho.Importer,
    slug: "ebird",
    version: "v2022",
    name: "eBird/Clements Checklist",
    description:
      "Clements, J. F., T. S. Schulenberg, M. J. Iliff, T. A. Fredericks, " <>
        "J. A. Gerbracht, D. Lepage, S. M. Billerman, B. L. Sullivan, and C. L. Wood. 2022. " <>
        "The eBird/Clements checklist of Birds of the World: v2022.\n" <>
        "Downloaded from https://www.birds.cornell.edu/clementschecklist/download/"

  def create_taxa(book) do
    create_taxa_from_csv(book, @prepared_taxonomy_file)
  end

  def create_taxa_from_csv(book, csv_file) do
    csv_file
    |> File.stream!([:trim_bom])
    |> CSV.decode(headers: true)
    |> Enum.reduce(%{}, fn {:ok, row}, taxa_cache ->

      {:ok, extras} = Jason.decode(row["extras"])
      attrs =
        row
        |> Map.put("parent_species_id", taxa_cache[row["parent_species_code"]])
        |> Map.put("extras", extras)

      {:ok, taxon} = Ornitho.create_taxon(book, attrs)

      new_cache =
        if row["category"] == "species" do
          Map.put(taxa_cache, row["code"], taxon.id)
        else
          taxa_cache
        end

      new_cache
    end)
  end
end
