defmodule Kjogvi.Geo.Dump do
  @moduledoc """
  Dumps a curated geo dataset to CSV.

  `run/1` writes the snapshot through the configured `Kjogvi.Datasets` storage
  (local files in dev/test, S3 in prod); `to_file/2` takes an explicit path,
  bypassing the storage config (bootstrap scripts, tests).

  Datasets:

  - `:common_locations` — every `user_id IS NULL` location with all curated
    columns, `extras` JSON-encoded. Rows are ordered parents-first (by
    hierarchy level, then id; specials last) so a restore can insert them in
    one pass. Special member links (`special_locations`) are not part of the
    dataset yet.
  - `:ebird_locations` — the eBird region reference including its match state
    (`location_id`), keyed and ordered by `code`; no `id` is carried (nothing
    references it).
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  @columns %{
    common_locations: ~w(
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
    )a,
    ebird_locations: ~w(
      code
      location_type
      country_code
      subnational1_code
      subnational2_code
      local_abbrev
      name
      name_long
      name_short
      nice_name
      location_id
    )a
  }

  # `special` sits outside the ordered levels; its level FKs point into the
  # hierarchy, so it sorts after everything it may reference.
  @level_order (Location.hierarchy_levels() ++ [:special]) |> Enum.with_index() |> Map.new()

  @storage_keys %{
    common_locations: "geo/common_locations.csv",
    ebird_locations: "geo/ebird_locations.csv"
  }

  def columns(dataset), do: Map.fetch!(@columns, dataset)

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

  defp dump(dataset, write) do
    :telemetry.span([:kjogvi, :geo, :dump], %{dataset: dataset}, fn ->
      rows = fetch(dataset)

      case write.(encode(rows, columns(dataset))) do
        :ok ->
          count = length(rows)
          {{:ok, count}, %{dataset: dataset, result: :ok, count: count}}

        {:error, reason} ->
          {{:error, reason}, %{dataset: dataset, result: :error, reason: reason}}
      end
    end)
  end

  defp fetch(:common_locations) do
    Location
    |> Query.only_common()
    |> Repo.all()
    |> Enum.sort_by(&{Map.fetch!(@level_order, &1.location_type), &1.id})
  end

  defp fetch(:ebird_locations) do
    EbirdLocation.Query.order_by_code()
    |> Repo.all()
  end

  defp encode(rows, columns) do
    header = Enum.map(columns, &Atom.to_string/1)
    data = Enum.map(rows, fn row -> Enum.map(columns, &encode_value(&1, row)) end)

    [header | data]
    |> CSV.encode()
    |> Enum.to_list()
    |> IO.iodata_to_binary()
  end

  defp encode_value(:extras, location), do: Jason.encode!(location.extras || %{})

  defp encode_value(column, row) do
    case Map.fetch!(row, column) do
      nil -> ""
      value -> to_string(value)
    end
  end
end
