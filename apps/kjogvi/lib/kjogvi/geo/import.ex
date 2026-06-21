defmodule Kjogvi.Geo.Import do
  @moduledoc """
  One-shot import of ISO 3166-1 (countries/territories) and ISO 3166-2
  (subdivisions) into `Kjogvi.Geo.Location` as `country` and `subdivision1`
  locations.

  Reads the pre-built `priv/geo/iso_3166.jsonl` file (see
  `priv/geo/build_iso_3166.exs`), which lists parents before children. Each row
  is inserted through `Location.changeset/2` with the parent's id as the virtual
  `parent_id`, so the level FK columns (`country_id` …) are derived from the
  parent. Assumes a clean (empty of ISO data) `locations` table.
  """

  alias Kjogvi.Geo.Location
  alias Kjogvi.Repo

  @default_path Application.app_dir(:kjogvi, "priv/geo/iso_3166.jsonl")

  def import(path \\ @default_path) do
    imported_at = DateTime.utc_now()

    Repo.transaction(
      fn ->
        path
        |> File.stream!()
        |> Stream.map(&Jason.decode!/1)
        |> Enum.reduce(%{}, fn row, ids_by_iso ->
          parent_id = parent_id(row, ids_by_iso)
          location = insert!(row, parent_id, imported_at)
          Map.put(ids_by_iso, row["iso_code"], location.id)
        end)
      end,
      timeout: :infinity
    )
  end

  defp parent_id(%{"parent_iso" => nil}, _ids_by_iso), do: nil

  defp parent_id(%{"parent_iso" => parent_iso, "iso_code" => iso}, ids_by_iso) do
    case Map.fetch(ids_by_iso, parent_iso) do
      {:ok, id} ->
        id

      :error ->
        Repo.rollback({:missing_parent, iso, parent_iso})
    end
  end

  defp insert!(row, parent_id, imported_at) do
    attrs = %{
      "slug" => slug(row["iso_code"]),
      "name_en" => row["name_en"],
      "location_type" => row["type"],
      "iso_code" => row["iso_code"],
      "is_private" => false,
      "parent_id" => parent_id,
      "extras" => extras(row, imported_at)
    }

    %Location{}
    |> Location.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, location} -> location
      {:error, changeset} -> Repo.rollback({:invalid, row["iso_code"], changeset})
    end
  end

  defp slug(iso_code) do
    iso_code |> String.downcase() |> String.replace("-", "_")
  end

  defp extras(row, imported_at) do
    %{
      "official_name" => row["official_name"],
      "numeric" => row["numeric"],
      "iso_codes_version" => row["iso_codes_version"],
      "imported_at" => DateTime.to_iso8601(imported_at)
    }
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
  end
end
