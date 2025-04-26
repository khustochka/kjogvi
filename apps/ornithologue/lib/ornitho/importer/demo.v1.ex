defmodule Ornitho.Importer.Demo.V1 do
  @moduledoc """
  Importer for a demo book. Also used in tests.
  """

  use Ornitho.Importer,
    slug: "demo",
    version: "v1",
    name: "Demo book",
    description: "This is a demo book",
    publication_date: ~D[2021-08-24]

  @taxa_list [
    %{
      name_sci: "Pica pica",
      name_en: "Eurasian Magpie",
      code: "eurmag1",
      category: "species",
      authority: "Linnaeus, 1758",
      authority_brackets: true,
      order: "Passeriformes",
      family: "Corvidae",
      sort_order: 1
    },
    %{
      name_sci: "Corvus cornix",
      name_en: "Hooded Crow",
      code: "hoocro1",
      category: "species",
      authority: "Linnaeus, 1758",
      authority_brackets: false,
      order: "Passeriformes",
      family: "Corvidae",
      sort_order: 2
    }
  ]

  @impl Ornitho.Importer
  def create_taxa(_config, book) do
    case Ops.Taxon.create_many(book, @taxa_list) do
      {:ok, rows} ->
        {:ok, length(Map.keys(rows))}

      {:error, _attrs, changeset, _} ->
        {:error, inspect(changeset.errors, pretty: true)}
    end
  end

  @impl Ornitho.Importer
  def validate_config do
    {:ok, nil}
  end
end
