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

  @impl Ornitho.StreamImporter
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
            # No need to cache all, it will be the last species
            %{row["code"] => taxon.id}

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
