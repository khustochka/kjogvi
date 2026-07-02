defmodule Kjogvi.Geo.Dump do
  @moduledoc """
  Dumps a curated geo dataset to CSV.

  `run/1` writes the snapshot through the configured `Kjogvi.Datasets` storage
  (local files in dev/test, S3 in prod); `to_file/2` takes an explicit path,
  bypassing the storage config (bootstrap scripts, tests).

  The only dataset so far is `:common_locations` — every `user_id IS NULL`
  location with all curated columns, `extras` JSON-encoded. Rows are ordered
  parents-first (by hierarchy level, then id; specials last) so a restore can
  insert them in one pass. Special member links (`special_locations`) are not
  part of the dataset yet.
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  @columns ~w(
    id
    slug
    name_en
    location_type
    iso_code
    lat
    lon
    is_private
    public_index
    import_source
    extras
    country_id
    subdivision1_id
    subdivision2_id
    city_id
    site_id
  )a

  # `special` sits outside the ordered levels; its level FKs point into the
  # hierarchy, so it sorts after everything it may reference.
  @level_order (Location.hierarchy_levels() ++ [:special]) |> Enum.with_index() |> Map.new()

  @storage_keys %{common_locations: "geo/common_locations.csv"}

  def columns, do: @columns

  @doc """
  The fixed snapshot key of a dataset — shared by dump and restore; history is
  kept by S3 bucket versioning, not by varying the key.
  """
  def storage_key(dataset), do: Map.fetch!(@storage_keys, dataset)

  @doc """
  Dumps `dataset` to the configured `Kjogvi.Datasets` storage. Returns
  `{:ok, row_count}`.
  """
  def run(dataset) do
    dump(dataset, &Datasets.write(storage_key(dataset), &1))
  end

  @doc """
  Dumps `dataset` to an explicit local `path`, bypassing the storage config.
  """
  def to_file(dataset, path) do
    dump(dataset, fn csv ->
      with :ok <- File.mkdir_p(Path.dirname(path)) do
        File.write(path, csv)
      end
    end)
  end

  defp dump(:common_locations = dataset, write) do
    :telemetry.span([:kjogvi, :geo, :dump], %{dataset: dataset}, fn ->
      locations = fetch_common_locations()

      case write.(encode(locations)) do
        :ok ->
          count = length(locations)
          {{:ok, count}, %{dataset: dataset, result: :ok, count: count}}

        {:error, reason} ->
          {{:error, reason}, %{dataset: dataset, result: :error, reason: reason}}
      end
    end)
  end

  defp fetch_common_locations do
    Location
    |> Query.only_common()
    |> Repo.all()
    |> Enum.sort_by(&{Map.fetch!(@level_order, &1.location_type), &1.id})
  end

  defp encode(locations) do
    header = Enum.map(@columns, &Atom.to_string/1)
    rows = Enum.map(locations, fn location -> Enum.map(@columns, &encode_value(&1, location)) end)

    [header | rows]
    |> CSV.encode()
    |> Enum.to_list()
    |> IO.iodata_to_binary()
  end

  defp encode_value(:extras, location), do: Jason.encode!(location.extras || %{})

  defp encode_value(column, location) do
    case Map.fetch!(location, column) do
      nil -> ""
      value -> to_string(value)
    end
  end
end
