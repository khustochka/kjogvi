defmodule Convertor.Ebird.V2025 do
  @moduledoc """
  Converts two checklist CSVs into one nice CSV for the importer.

  This one is for Clements/eBird v2025.

  Run from the umbrella root:

  ```bash
  mix run apps/ornithologue/scripts/convertor/ebird.v2025.exs
  ```
  """

  @convert_dir Path.join(:code.priv_dir(:ornithologue), "convert/ebird/v2025")

  @extras_conversion %{
    "TAXON_ORDER" => {:integer, :ebird_order},
    "SPECIES_GROUP" => {:string, :species_group},
    "Clements v2025 change" => {:string, :change_type},
    "text for website v2025" => {:string, :change_text},
    "range" => {:string, :range},
    "extinct" => {:boolean, :extinct},
    "extinct year" => {:string, :extinct_year}
  }

  @ebird_taxonomy_file Path.join(@convert_dir, "eBird_taxonomy_v2025.csv")
  @clements_checklist_file Path.join(
                             @convert_dir,
                             "eBird-Clements_v2025-integrated-checklist-October-2025.csv"
                           )
  # Download from https://api.ebird.org/v2/ref/taxonomy/ebird?version=2025 (no auth needed)
  @api_taxonomy_file Path.join(@convert_dir, "API_eBird_taxonomy_v2025.csv")
  @output_file Path.join(@convert_dir, "ornithologue_ebird_v2025.csv")

  # Explicit output column order. The attrs keyword lists are reshuffled by the amend
  # steps (`Keyword.put` prepends new keys), so the header is fixed here rather than
  # derived from the data. `extras` goes last.
  @output_headers [
    :name_sci,
    :name_en,
    :code,
    :category,
    :authority,
    :authority_brackets,
    :order,
    :family,
    :taxon_concept_id,
    :sort_order,
    :parent_species_code,
    :com_name_codes,
    :sci_name_codes,
    :banding_codes,
    :extras
  ]

  def convert do
    extract_taxa_from_csv(@ebird_taxonomy_file)
    |> amend_taxa_from_csv(@clements_checklist_file)
    |> amend_codes_from_csv(@api_taxonomy_file)
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

        attrs = [
          name_sci: row["SCI_NAME"],
          name_en: row["PRIMARY_COM_NAME"],
          # taxon_concept_id: row["TAXON_CONCEPT_ID"],
          code: row["SPECIES_CODE"],
          category: row["CATEGORY"],
          order: row["ORDER"],
          family: family,
          com_name_codes: "",
          sci_name_codes: "",
          banding_codes: "",
          extras: encoded_extras,
          sort_order: sort_order,
          parent_species_code: row["REPORT_AS"],
          authority: nil,
          authority_brackets: nil
        ]

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

      taxon_concept_id = row["taxon concept ID"]

      if not is_nil(taxon) do
        {:ok, old_extras} = taxon[:extras] |> Jason.decode()
        new_extras = old_extras |> Map.merge(extract_extras(row))
        {authority, authority_brackets} = extract_authority(row["authority"])
        {:ok, encoded_extras} = new_extras |> Jason.encode()

        taxon_updated =
          taxon
          |> Keyword.put(:taxon_concept_id, taxon_concept_id)
          |> Keyword.merge(
            extras: encoded_extras,
            authority: authority,
            authority_brackets: authority_brackets
          )

        taxa_cache
        |> Map.put(name_sci, taxon_updated)
      else
        taxa_cache
      end
    end)
  end

  # The API taxonomy file is keyed by SPECIES_CODE, while the cache is keyed by SCI_NAME,
  # so index the cache by code first, then amend each matched taxon with its codes and
  # family_code (the latter stashed in extras).
  def amend_codes_from_csv(taxa, csv_file) do
    sci_name_by_code =
      Map.new(taxa, fn {sci_name, attrs} -> {attrs[:code], sci_name} end)

    csv_file
    |> File.stream!([:trim_bom])
    |> CSV.decode(headers: true)
    |> Enum.reduce(taxa, fn {:ok, row}, taxa_cache ->
      sci_name = sci_name_by_code[row["SPECIES_CODE"]]
      taxon = sci_name && taxa_cache[sci_name]

      if is_nil(taxon) do
        taxa_cache
      else
        {:ok, old_extras} = taxon[:extras] |> Jason.decode()
        new_extras = put_family_code(old_extras, row["FAMILY_CODE"])
        {:ok, encoded_extras} = new_extras |> Jason.encode()

        taxon_updated =
          taxon
          |> Keyword.put(:com_name_codes, normalize_codes(row["COM_NAME_CODES"]))
          |> Keyword.put(:sci_name_codes, normalize_codes(row["SCI_NAME_CODES"]))
          |> Keyword.put(:banding_codes, normalize_codes(row["BANDING_CODES"]))
          |> Keyword.put(:extras, encoded_extras)

        Map.put(taxa_cache, sci_name, taxon_updated)
      end
    end)
  end

  # Uppercases and deduplicates a space-separated codes cell.
  defp normalize_codes(value) do
    value
    |> to_string()
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&String.upcase/1)
    |> Enum.uniq()
    |> Enum.join(" ")
  end

  defp put_family_code(extras, value) do
    case value do
      str when is_binary(str) and str != "" -> Map.put(extras, "family_code", str)
      _ -> extras
    end
  end

  def save_csv(taxa, csv_file) do
    file = File.open!(csv_file, [:write, :utf8])

    values =
      taxa
      |> Map.values()
      |> Enum.sort_by(&Keyword.get(&1, :sort_order))

    values
    |> Enum.map(&Map.new/1)
    |> CSV.encode(headers: @output_headers)
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
  defp extract_authority(nil), do: {nil, nil}

  defp extract_authority(authority) do
    {
      Regex.named_captures(~r/\A\(?(?<authority>[^\)]*)\)?\Z/, authority)["authority"],
      String.starts_with?(authority, "(")
    }
  end
end

Convertor.Ebird.V2025.convert()
