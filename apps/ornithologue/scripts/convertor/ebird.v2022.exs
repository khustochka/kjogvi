defmodule Convertor.Ebird.V2022 do
  @moduledoc """
  Converts two checklist CSVs into one nice CSV for the importer.
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
  @output_file "priv/import/ebird/v2022/ornithologue_ebird_v2022.csv"

  def convert do
    extract_taxa_from_csv(@ebird_taxonomy_file)
    |> amend_taxa_from_csv(@clements_checklist_file)
    |> save_csv(@output_file)
  end

  def extract_taxa_from_csv(csv_file) do
    {_, taxa} =
      csv_file
      |> File.stream!([:trim_bom])
      |> CSV.decode(headers: true)
      |> Enum.reduce({1, %{}}, fn {:ok, row}, {sort_order, taxa_acc} ->
        family =
          case row["FAMILY"] do
            "" -> nil
            str -> Regex.run(~r/\A\w+dae/, str) |> List.first()
          end

        {:ok, encoded_extras} = Jason.encode(extract_extras(row))

        attrs = %{
          name_sci: row["SCI_NAME"],
          name_en: row["PRIMARY_COM_NAME"],
          code: row["SPECIES_CODE"],
          category: row["CATEGORY"],
          order: row["ORDER1"],
          family: family,
          extras: encoded_extras,
          sort_order: sort_order,
          parent_species_code: row["REPORT_AS"],
          authority: nil,
          authority_brackets: nil
        }

        new_cache = Map.put(taxa_acc, row["SCI_NAME"], attrs)

        {sort_order + 1, new_cache}
      end)

    taxa
  end

  def amend_taxa_from_csv(taxa, csv_file) do
    csv_file
    |> File.stream!([:trim_bom])
    |> CSV.decode(headers: true)
    |> Enum.reduce(taxa, fn {:ok, row}, taxa_cache ->
      name_sci = row["scientific name"]
      taxon = taxa_cache[name_sci]

      if not is_nil(taxon) do


      {:ok, old_extras} = taxon.extras |> Jason.decode
        new_extras = old_extras |> Map.merge(extract_extras(row))
        {authority, authority_brackets} = extract_authority(row["authority"])
        {:ok, encoded_extras} = new_extras |> Jason.encode
        taxon_updated =
          taxon
          |> Map.merge(%{extras: encoded_extras, authority: authority, authority_brackets: authority_brackets})
          taxa_cache
        |> Map.put(name_sci, taxon_updated)
      else
        taxa_cache
      end
    end)
  end

  def save_csv(taxa, csv_file) do
    file = File.open!(csv_file, [:write, :utf8])

    values =
      taxa
      |> Map.values()
      |> Enum.sort_by(&(Map.get(&1, :sort_order)))
    headers = values |> List.first |> Map.keys
    values
    |> CSV.encode(headers: headers)
    |> Enum.each(&IO.write(file, &1))
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

Convertor.Ebird.V2024.convert()
