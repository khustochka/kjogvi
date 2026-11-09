defmodule Converter.AviList.V2026 do
  @moduledoc """
  Converts the checklist CSV into a simpler one for the importer.

  This one is for AviList v2026 (extended version). Compared to v2025, the
  column headers are renamed (e.g. `#`, `RANK`, `SCIENTIFIC NAME`) and there is
  no family English name column: it is taken from the family row's AviList
  English name instead.

  Run from the umbrella root:

  ```bash
  mix run apps/ornithologue/scripts/converter/avilist.v2026.exs
  ```
  """

  @extras_conversion %{
    "#" => {:integer, :avilist_order},
    "RANGE" => {:string, :range},
    "EXTINCTION STATUS" => {:string, :extinction_status},
    "IUCN RED LIST CATEGORY" => {:string, :iucn_red_list_category},
    "SPECIES CODE CORNELL LAB" => {:string, :ebird_code}
  }

  @extinct_statuses ["Extinct", "(extinct)"]

  @convert_dir Path.join(:code.priv_dir(:ornithologue), "convert/avilist/v2026")

  @taxonomy_file Path.join(@convert_dir, "AviList-v2026-20Oct2026-extended-version.csv")
  @output_file Path.join(
                 :code.priv_dir(:ornithologue),
                 "import/avilist/v2026/ornithologue_avilist_v2026.csv"
               )

  def convert do
    extract_taxa_from_csv(@taxonomy_file)
    |> save_csv(@output_file)
  end

  def extract_taxa_from_csv(csv_file) do
    {_, _, _, taxa} =
      csv_file
      |> File.stream!([:trim_bom])
      |> CSV.decode(headers: true)
      |> Enum.reduce({1, nil, {nil, nil}, []}, fn {:ok, row}, acc ->
        reduce_row(row["RANK"], row, acc)
      end)

    Enum.reverse(taxa)
  end

  defp reduce_row("family", row, {sort_order, _family_en, _last_species, taxa}) do
    {sort_order, row["ENGLISH NAME: AVILIST"], {nil, nil}, taxa}
  end

  defp reduce_row(rank, row, {sort_order, family_en, last_species, taxa})
       when rank in ["species", "subspecies"] do
    attrs = taxon_attrs(rank, row, sort_order, family_en, last_species)

    new_last_species =
      case rank do
        "species" -> {attrs[:code], attrs[:name_en]}
        "subspecies" -> last_species
      end

    {sort_order + 1, family_en, new_last_species, [attrs | taxa]}
  end

  defp reduce_row(_rank, _row, {sort_order, family_en, _last_species, taxa}) do
    {sort_order, family_en, {nil, nil}, taxa}
  end

  defp taxon_attrs(rank, row, sort_order, family_en, {last_species_code, last_species_name_en}) do
    code = row["#"] |> String.pad_leading(5, "0")

    {authority, authority_brackets} = extract_authority(row["AUTHORITY"])

    parent_species_code =
      case rank do
        "species" -> nil
        "subspecies" -> last_species_code
      end

    name_en =
      case {rank, row["ENGLISH NAME: AVILIST"]} do
        {_, name} when name != "" ->
          name

        {"subspecies", ""} when is_binary(last_species_name_en) ->
          subspecies_epithet =
            row["SCIENTIFIC NAME"]
            |> String.split(" ")
            |> List.last()

          "#{last_species_name_en} (#{subspecies_epithet})"
      end

    {:ok, encoded_extras} =
      row
      |> extract_extras()
      |> Map.put(:species_group, family_en)
      |> then(fn extras ->
        if extras[:extinction_status] in @extinct_statuses do
          Map.put(extras, :extinct, true)
        else
          extras
        end
      end)
      |> Jason.encode()

    [
      code: code,
      sort_order: sort_order,
      category: rank,
      name_sci: row["SCIENTIFIC NAME"],
      name_en: name_en,
      order: row["ORDER"],
      family: row["FAMILY"],
      authority: authority,
      authority_brackets: authority_brackets,
      taxon_concept_id: row["AVIBASE ID"],
      protonym: row["PROTONYM"],
      extras: encoded_extras,
      parent_species_code: parent_species_code
    ]
  end

  def save_csv(taxa, csv_file) do
    File.mkdir_p!(Path.dirname(csv_file))
    file = File.open!(csv_file, [:write, :utf8])

    headers = taxa |> List.first() |> Keyword.keys()

    taxa
    |> Enum.map(&Map.new/1)
    |> CSV.encode(headers: headers)
    |> Enum.each(&IO.write(file, &1))
  end

  defp extract_extras(row) do
    Enum.reduce(@extras_conversion, %{}, fn {key, {type, field}}, acc ->
      add_converted_key(type, row[key], field)
      |> Map.merge(acc)
    end)
  end

  defp add_converted_key(_type, "", _field), do: %{}
  defp add_converted_key(:string, value, field), do: %{field => value}
  defp add_converted_key(:integer, value, field), do: %{field => String.to_integer(value)}

  # returns {authority_string, has_brackets?}
  defp extract_authority(""), do: {nil, nil}

  defp extract_authority(authority) do
    {
      Regex.named_captures(~r/\A\(?(?<authority>[^\)]*)\)?\Z/, authority)["authority"],
      String.starts_with?(authority, "(")
    }
  end
end

Converter.AviList.V2026.convert()
