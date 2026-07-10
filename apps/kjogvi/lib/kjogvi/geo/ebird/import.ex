defmodule Kjogvi.Geo.Ebird.Import do
  @moduledoc """
  Bootstrap import of eBird's region tree into `Kjogvi.Geo.EbirdLocation`.

  Reads eBird's region dump (`all_ebird_locs.json`) — a JSON map of region
  code to attributes — and bulk-upserts one row per region.

  The source file lives in the `Kjogvi.Datasets` snapshot storage under
  `source_key/0` (`geo/sources/all_ebird_locs.json`) — local files in
  dev/test, S3 in prod — and is *read-only* from the app's side: it is
  uploaded to the storage out-of-band, never written by the app. `import/0`
  reads it from there (the admin imports card); `from_json/1` takes an
  explicit local path, bypassing the storage config (bootstrap scripts,
  tests). The curated snapshot (`Kjogvi.Geo.Dump`) remains the canonical
  seed — this import is for bootstrap and newer eBird dumps.

  ## Re-runnable upsert

  Upserts on `code`: the name/code columns are refreshed from the dump, while
  `location_id` — the curated match state — is never touched, and rows are
  never deleted. Entries with no `countryCode` (pseudo-regions like `"aba"`)
  are skipped and reported in the result.
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  # ~13 bind parameters per row; keeps a batch well under Postgres's 65535
  # bind-parameter limit.
  @chunk_size 3000

  @source_key "geo/sources/all_ebird_locs.json"

  @doc """
  The source file's fixed key in the `Kjogvi.Datasets` storage.
  """
  def source_key, do: @source_key

  @doc """
  Imports the eBird region JSON read from the configured `Kjogvi.Datasets`
  storage (`source_key/0`). `{:error, :enoent}` when no source file has been
  uploaded yet; `{:ok, %{count: n, skipped: [code, ...]}}` on success.
  """
  def import do
    with {:ok, body} <- Datasets.read(@source_key) do
      body
      |> Jason.decode!()
      |> run()
    end
  end

  @doc """
  Imports the eBird region JSON from an explicit local `path`, bypassing the
  storage config. Returns `{:ok, %{count: n, skipped: [code, ...]}}`.
  """
  def from_json(path) do
    path
    |> File.read!()
    |> Jason.decode!()
    |> run()
  end

  defp run(entries) do
    :telemetry.span([:kjogvi, :geo, :ebird, :import], %{}, fn ->
      {rows, skipped} = parse(entries)
      result = upsert_all(rows, skipped)
      {result, stop_metadata(result)}
    end)
  end

  defp stop_metadata({:ok, %{count: count, skipped: skipped}}),
    do: %{result: :ok, count: count, skipped: skipped}

  defp stop_metadata({:error, reason}), do: %{result: :error, reason: reason}

  defp parse(entries) do
    now = DateTime.utc_now()
    {valid, malformed} = Enum.split_with(entries, fn {_code, attrs} -> attrs["countryCode"] end)

    rows =
      valid
      |> Enum.map(fn {code, attrs} -> row(code, attrs, now) end)
      |> Enum.sort_by(& &1.code)

    {rows, malformed |> Enum.map(&elem(&1, 0)) |> Enum.sort()}
  end

  defp upsert_all(rows, skipped) do
    Repo.transaction(
      fn ->
        count =
          rows
          |> Enum.chunk_every(@chunk_size)
          |> Enum.map(&upsert_chunk/1)
          |> Enum.sum()

        %{count: count, skipped: skipped}
      end,
      timeout: :infinity
    )
  end

  defp upsert_chunk(rows) do
    {count, _} =
      Repo.insert_all(EbirdLocation, rows,
        on_conflict: {:replace, replace_columns()},
        conflict_target: [:code]
      )

    count
  end

  # Refresh everything the dump carries; never `location_id` (curated match
  # state) or `inserted_at`.
  defp replace_columns do
    ~w(location_type country_code subnational1_code subnational2_code
       local_abbrev name name_long name_short nice_name updated_at)a
  end

  defp row(code, attrs, now) do
    %{
      code: code,
      location_type: location_type(attrs),
      country_code: attrs["countryCode"],
      subnational1_code: presence(attrs["subnational1Code"]),
      subnational2_code: presence(attrs["subnational2Code"]),
      local_abbrev: presence(attrs["localAbbrev"]),
      name: presence(attrs["name"]),
      name_long: presence(attrs["nameLong"]),
      name_short: presence(attrs["nameShort"]),
      nice_name: presence(attrs["niceName"]),
      inserted_at: now,
      updated_at: now
    }
  end

  defp location_type(%{"subnational2Code" => _}), do: :subdivision2
  defp location_type(%{"subnational1Code" => _}), do: :subdivision1
  defp location_type(_), do: :country

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value
end
