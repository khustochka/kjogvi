defmodule Kjogvi.Geo.Ebird.Import do
  @moduledoc """
  Bootstrap import of eBird's region tree into `Kjogvi.Geo.EbirdLocation`.

  Reads eBird's region dump (`ebird_subregions.jsonl`) — JSON Lines, one
  `{code, name, level, parent_code}` object per line — and bulk-upserts one
  row per region. The split-out `country_code` / `subnational1_code` /
  `subnational2_code` columns the matcher relies on are derived from the
  eBird `code` itself (`"US-CA-037"` → country `"US"`, sub1 `"US-CA"`,
  sub2 `"US-CA-037"`), since eBird codes encode the hierarchy.

  The source file lives in the `Kjogvi.Datasets` snapshot storage under
  `source_key/0` (`geo/sources/ebird_subregions.jsonl`) — local files in
  dev/test, S3 in prod — and is *read-only* from the app's side: it is
  uploaded to the storage out-of-band, never written by the app. `import/0`
  reads it from there (the admin imports card); `from_jsonl/1` takes an
  explicit local path, bypassing the storage config (bootstrap scripts,
  tests). The curated snapshot (`Kjogvi.Geo.Dump`) remains the canonical
  seed — this import is for bootstrap and newer eBird dumps.

  ## Re-runnable upsert

  Upserts on `code`: the name/code columns are refreshed from the dump, while
  `location_id` — the curated match state — is never touched, and rows are
  never deleted. Entries with an unrecognized `level` are skipped and
  reported in the result.
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Repo

  # ~8 bind parameters per row; keeps a batch well under Postgres's 65535
  # bind-parameter limit.
  @chunk_size 3000

  @source_key "geo/sources/ebird_subregions.jsonl"

  @levels %{
    "country" => :country,
    "subregion1" => :subdivision1,
    "subregion2" => :subdivision2
  }

  @doc """
  The source file's fixed key in the `Kjogvi.Datasets` storage.
  """
  def source_key, do: @source_key

  @doc """
  Imports the eBird region JSONL read from the configured `Kjogvi.Datasets`
  storage (`source_key/0`). `{:error, :enoent}` when no source file has been
  uploaded yet; `{:ok, %{count: n, skipped: [code, ...]}}` on success.
  """
  def import do
    with {:ok, body} <- Datasets.read(@source_key) do
      body
      |> decode_jsonl()
      |> run()
    end
  end

  @doc """
  Imports the eBird region JSONL from an explicit local `path`, bypassing the
  storage config. Returns `{:ok, %{count: n, skipped: [code, ...]}}`.
  """
  def from_jsonl(path) do
    path
    |> File.read!()
    |> decode_jsonl()
    |> run()
  end

  defp decode_jsonl(body) do
    body
    |> String.split("\n", trim: true)
    |> Enum.map(&Jason.decode!/1)
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
    {valid, malformed} = Enum.split_with(entries, &Map.has_key?(@levels, &1["level"]))

    rows =
      valid
      |> Enum.map(&row(&1, now))
      |> Enum.sort_by(& &1.code)

    {rows, malformed |> Enum.map(& &1["code"]) |> Enum.sort()}
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
    ~w(location_type country_code subnational1_code subnational2_code name updated_at)a
  end

  defp row(%{"code" => code, "level" => level} = attrs, now) do
    {country_code, subnational1_code, subnational2_code} = ancestor_codes(code)

    %{
      code: code,
      location_type: Map.fetch!(@levels, level),
      country_code: country_code,
      subnational1_code: subnational1_code,
      subnational2_code: subnational2_code,
      name: presence(attrs["name"]),
      inserted_at: now,
      updated_at: now
    }
  end

  # eBird codes encode the hierarchy: `US-CA-037` → country `US`,
  # subnational1 `US-CA`, subnational2 `US-CA-037`.
  defp ancestor_codes(code) do
    case String.split(code, "-") do
      [country] -> {country, nil, nil}
      [country, _] -> {country, code, nil}
      [country, sub1 | _] -> {country, "#{country}-#{sub1}", code}
    end
  end

  defp presence(nil), do: nil
  defp presence(""), do: nil
  defp presence(value), do: value
end
