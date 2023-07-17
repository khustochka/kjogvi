defmodule Ornitho.Importer.Demo.V1 do
  @moduledoc """
  Importer for a demo book. Also used in tests.
  """

  use Ornitho.Importer,
    slug: "demo",
    version: "v1",
    name: "Demo book",
    description: "This is a demo book"

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

  def create_taxa(book) do
    case Ops.Taxon.create_many(book, @taxa_list) do
      {:ok, m} ->
        {:ok, m}

      {:error, attrs, changeset, _} ->
        raise """
        Failed to insert:
        #{inspect(attrs, pretty: true)};
        errors:
        #{inspect(changeset.errors, pretty: true)}
        """
    end
  end
end
