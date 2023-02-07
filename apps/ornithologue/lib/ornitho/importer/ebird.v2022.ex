defmodule Ornitho.Importer.Ebird.V2022 do
  @moduledoc """
  Importer for eBird/Clements checklist version 2022.
  """

  @extras_conversion %{
    "TAXON_ORDER" => {:integer, :ebird_order},
    "SPECIES_GROUP" => {:string, :species_group},
    "Clements v2022 change" => {:string, :change_type},
    "text for website v2022" => {:string, :change_text},
    "range" => {:string, :range},
    "extinct" => {:boolean, :extinct},
    "extinct year" => {:string, :extinct_year}
  }

  @ebird_taxonomy_file "priv/import/ebird/v2022/ebird_taxonomy_v2022.csv"
  @clements_checklist_file "priv/import/ebird/v2022/NEW_Clements-Checklist-v2022-October-2022.csv"

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
    create_taxa_from_csv(book, @ebird_taxonomy_file)
    amend_taxa_from_csv(book, @clements_checklist_file)
  end

  def create_taxa_from_csv(book, csv_file) do
    csv_file
    |> File.stream!([:trim_bom])
    |> CSV.decode(headers: true)
    |> Enum.reduce({1, %{}}, fn {:ok, row}, {sort_order, species_cache} ->
      family =
        case row["FAMILY"] do
          "" -> nil
          str -> Regex.run(~r/\A\w+dae/, str) |> List.first()
        end

      attrs = %{
        name_sci: row["SCI_NAME"],
        name_en: row["PRIMARY_COM_NAME"],
        code: row["SPECIES_CODE"],
        category: row["CATEGORY"],
        order: row["ORDER1"],
        family: family,
        extras: extract_extras(row),
        sort_order: sort_order,
        parent_species_id: species_cache[row["REPORT_AS"]]
      }

      {:ok, taxon} = Ornitho.create_taxon(book, attrs)

      new_cache =
        if row["CATEGORY"] == "species" do
          Map.put(species_cache, row["SPECIES_CODE"], taxon.id)
        else
          species_cache
        end

      {sort_order + 1, new_cache}
    end)
  end

  defp amend_taxa_from_csv(book, csv_file) do
    csv_file
    |> File.stream!([:trim_bom])
    |> CSV.decode(headers: true)
    |> Enum.each(fn {:ok, row} ->
      taxon = Ornitho.Find.Taxon.by_name_sci(book, row["scientific name"])

      if not is_nil(taxon) do
        new_extras = taxon.extras |> Map.merge(extract_extras(row))
        {authority, authority_brackets} = extract_authority(row["authority"])

        Ornitho.update_taxon(
          taxon,
          %{extras: new_extras, authority: authority, authority_brackets: authority_brackets}
        )
      end
    end)
  end

  defp extract_extras(row) do
    Map.keys(@extras_conversion)
    |> Enum.reduce(%{}, fn key, acc ->
      {type, field} = @extras_conversion[key]

      add_converted_key(type, row[key], field)
      |> Map.merge(acc)
    end)
  end

  defp add_converted_key(:string, value, field) do
    with str when is_binary(str) and str != "" <- value do
      %{field => str}
    else
      _ -> %{}
    end
  end

  defp add_converted_key(:integer, value, field) do
    with str when is_binary(str) and str != "" <- value do
      %{field => String.to_integer(str)}
    else
      _ -> %{}
    end
  end

  defp add_converted_key(:boolean, value, field) do
    with "1" <- value do
      %{field => true}
    else
      _ -> %{}
    end
  end

  # {authority_string, has_brackets?}
  defp extract_authority("" = _authority), do: {nil, nil}

  defp extract_authority(authority) do
    {
      Regex.named_captures(~r/\A\(?(?<authority>[^\)]*)\)?\Z/, authority)["authority"],
      String.starts_with?(authority, "(")
    }
  end
end
