defmodule Convertor.AviList.V2025 do
  @moduledoc """
  Converts the checklist CSV into a simpler one for the importer.

  This one is for AviList v2025.

  Run:

  ```bash
  mix run scripts/convertor/avilist.v2025.exs
  ```
  """

  @extras_conversion %{
    "Sequence" => {:integer, :avilist_order},
    "Family_English_name" => {:string, :species_group},
    "Range" => {:string, :range},
    "IUCN_Red_List_Category" => {:string, :iucn_red_list_category},
    "Species_code_Cornell_Lab" => {:string, :ebird_code}
  }

  @taxonomy_file "priv/convert/avilist/v2025/AviList-v2025-11Jun-extended.csv"
  @output_file "priv/convert/avilist/v2025/ornithologue_avilist_v2025.csv"

  def convert do
    extract_taxa_from_csv(@taxonomy_file)
    |> save_csv(@output_file)
  end

  def extract_taxa_from_csv(csv_file) do
    {_, _, taxa} =
      csv_file
      |> File.stream!([:trim_bom])
      |> CSV.decode(headers: true)
      |> Enum.reduce(
        {1, {nil, nil}, []},
        fn {:ok, row}, {sort_order, {last_species_code, last_species_name_en}, taxa_acc} ->
          taxon_rank = row["Taxon_rank"]

          if taxon_rank in ["species", "subspecies"] do
            code = row["Sequence"] |> String.pad_leading(5, "0")

            {authority, authority_brackets} = extract_authority(row["Authority"])

            parent_species_code =
              if taxon_rank == "species" do
                nil
              else
                last_species_code
              end

            name_en_raw = row["English_name_AviList"]

            name_en =
              cond do
                is_binary(name_en_raw) and name_en_raw != "" ->
                  name_en_raw

                taxon_rank == "subspecies" and not is_nil(last_species_name_en) ->
                  subspecies_epithet =
                    row["Scientific_name"]
                    |> String.split(" ")
                    |> List.last()

                  "#{last_species_name_en} (#{subspecies_epithet})"

                :else ->
                  raise "Invalid state"
              end

            {:ok, encoded_extras} =
              extract_extras(row)
              |> then(fn extras ->
                if extras[:extinction_status] in ["Extinct", "(extinct)"] do
                  Map.put(extras, :extinct, true)
                else
                  extras
                end
              end)
              |> Jason.encode()

            attrs =
              [
                code: code,
                sort_order: sort_order,
                category: taxon_rank,
                name_sci: row["Scientific_name"],
                name_en: name_en,
                order: row["Order"],
                family: row["Family"],
                authority: authority,
                authority_brackets: authority_brackets,
                taxon_concept_id: row["AvibaseID"],
                protonym: row["Protonym"],
                extras: encoded_extras,
                parent_species_code: parent_species_code
              ]

            new_last_species_tuple =
              case taxon_rank do
                "species" -> {code, name_en}
                "subspecies" -> {last_species_code, last_species_name_en}
              end

            new_taxa_list = [attrs | taxa_acc]

            {sort_order + 1, new_last_species_tuple, new_taxa_list}
          else
            {sort_order, {nil, nil}, taxa_acc}
          end
        end
      )

    Enum.reverse(taxa)
  end

  def save_csv(taxa, csv_file) do
    file = File.open!(csv_file, [:write, :utf8])

    headers = taxa |> List.first() |> Keyword.keys()

    taxa
    |> Enum.map(&Map.new/1)
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

  # returns {authority_string, has_brackets?}
  defp extract_authority("" = _authority), do: {nil, nil}
  defp extract_authority(nil), do: {nil, nil}

  defp extract_authority(authority) do
    {
      Regex.named_captures(~r/\A\(?(?<authority>[^\)]*)\)?\Z/, authority)["authority"],
      String.starts_with?(authority, "(")
    }
  end
end

Convertor.AviList.V2025.convert()
