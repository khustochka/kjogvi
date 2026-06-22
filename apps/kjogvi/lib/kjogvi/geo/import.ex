defmodule Kjogvi.Geo.Import do
  @moduledoc """
  One-shot import of ISO 3166-1 (countries/territories) and ISO 3166-2
  (subdivisions) into `Kjogvi.Geo.Location` as `country` and `subdivision1`
  locations.

  Reads a pre-built JSONL file (see `priv/geo/build_iso_3166.exs`), one location
  per line. The data is strictly two-level — countries, then their subdivisions —
  so it is bulk-inserted with `Repo.insert_all` in two passes (countries first,
  then subdivisions with `country_id` taken from the countries just inserted)
  rather than one changeset per row, keeping the whole import well under a second.

  The single entry point is `import/2`, which dispatches on its source: an
  `http(s)://` URL is fetched over HTTP, any other string is a local file path,
  and the default is the configured URL (`default_url/0`, never hardcoded). The
  generated data is hosted out-of-band (e.g. a GitHub release asset) rather than
  committed, so a fresh deployment can fill an empty `locations` table from the
  configured URL without a shell or the `iso-codes` package on the host.

  The dataset is small (a few hundred KB), so the HTTP body is buffered whole
  rather than streamed end-to-end; only the local-file path streams from disk.

  Both refuse to run when ISO data is already present (`country_exists?/0`),
  so the import stays a clean one-shot.

  TODO: re-import / upsert path. This importer assumes an empty table; it has no
  reconciliation for a *re-run* against an existing dataset (new iso-codes
  version, renamed country, added/removed subdivision). A future version should
  match on `iso_code` and update `name_en`/`extras` while preserving each row's
  `id` (cards reference locations by id) and any user edits, and decide what to
  do with subdivisions that disappear from a newer ISO release but still have
  cards. Until then, `country_exists?/0` blocks any second run.
  """

  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  # Imported locations start at this id, reserving the lower range for
  # hand-managed rows. The sequence is bumped to at least this value (or past the
  # current max id) before the import inserts anything.
  @min_start_seq 10_000

  @doc """
  Imports the ISO 3166 JSONL from `source`.

  `source` selects where the data comes from, and defaults to the configured URL
  (`default_url/0`):

    * an `http(s)://` URL — fetched over HTTP into memory (the production path);
    * any other string — a local file path, streamed from disk (dev/tests);
    * omitted — the configured URL, or a clear raise when it is unset.

  `opts[:req_options]` is merged into the `Req` request (HTTP source only),
  which lets tests inject a plug instead of hitting the network.
  """
  def import(source \\ default_url(), opts \\ [])

  def import(nil, _opts), do: raise(missing_url_message())

  def import("http" <> _ = url, opts) do
    req_options = Keyword.get(opts, :req_options, [])

    %Req.Response{status: 200, body: body} =
      Req.get!([url: url] ++ req_options)

    body
    |> String.split("\n", trim: true)
    |> run()
  end

  def import(path, _opts) when is_binary(path) do
    path
    |> File.stream!()
    |> run()
  end

  @doc """
  The configured JSONL URL, or `nil` when unset.

      config :kjogvi, Kjogvi.Geo.Import, url: "https://.../iso_3166.jsonl"
  """
  def default_url do
    :kjogvi
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:url)
  end

  @doc """
  Whether any `country` location already exists. The import refuses to run when
  it does, keeping it a one-shot fill of an empty table.
  """
  def country_exists? do
    Location
    |> Query.countries()
    |> Repo.exists?()
  end

  # Runs the import for a stream/enumerable of JSONL lines (strings). Refuses
  # when ISO data is already present, then inserts every row in one transaction,
  # parents before children, resolving each child's parent by iso_code.
  #
  # Wrapped in a `:telemetry.span/3` so the whole run's duration is measured; the
  # `:stop` metadata carries the outcome and, on success, the number of locations
  # inserted (see `stop_metadata/1`).
  defp run(lines) do
    :telemetry.span([:kjogvi, :geo, :import], %{}, fn ->
      result =
        if country_exists?() do
          {:error, :already_imported}
        else
          insert_all(lines)
        end

      {result, stop_metadata(result)}
    end)
  end

  defp stop_metadata({:ok, ids_by_iso}), do: %{result: :ok, count: map_size(ids_by_iso)}
  defp stop_metadata({:error, reason}), do: %{result: :error, reason: reason}

  # The data is strictly two-level (countries, then their subdivisions), so the
  # rows are bulk-inserted with `Repo.insert_all` in two passes instead of one
  # changeset + parent lookup per row: countries first, then subdivisions with
  # `country_id` taken from the countries' returned ids. Returns the same
  # `%{iso_code => id}` map the per-row version did.
  defp insert_all(lines) do
    imported_at = DateTime.utc_now()
    parsed = Enum.map(lines, &Jason.decode!/1)
    {countries, subdivisions} = Enum.split_with(parsed, &(&1["parent_iso"] == nil))

    Repo.transaction(
      fn ->
        bump_id_sequence()
        ids_by_iso = insert_countries(countries, imported_at)
        insert_subdivisions(subdivisions, ids_by_iso, imported_at)
      end,
      timeout: :infinity
    )
  end

  # Move `locations_id_seq` to at least `@min_start_seq`, but never below the
  # current max id, so imported rows take ids in the reserved upper range without
  # colliding with any existing row.
  defp bump_id_sequence do
    Repo.query!(
      "SELECT setval('locations_id_seq', GREATEST($1, (SELECT COALESCE(MAX(id), 0) FROM locations)))",
      [@min_start_seq]
    )
  end

  defp insert_countries(countries, imported_at) do
    rows = Enum.map(countries, &base_row(&1, imported_at))

    {_, inserted} = Repo.insert_all(Location, rows, returning: [:id, :iso_code])

    Map.new(inserted, &{&1.iso_code, &1.id})
  end

  defp insert_subdivisions(subdivisions, ids_by_iso, imported_at) do
    rows =
      Enum.map(subdivisions, fn row ->
        country_id = country_id!(row, ids_by_iso)
        Map.put(base_row(row, imported_at), :country_id, country_id)
      end)

    # Each row carries ~9 columns; chunk so a batch stays well under Postgres's
    # 65535 bind-parameter limit.
    rows
    |> Enum.chunk_every(5000)
    |> Enum.each(&Repo.insert_all(Location, &1))

    Map.merge(ids_by_iso, Map.new(rows, &{&1.iso_code, nil}))
  end

  defp country_id!(%{"parent_iso" => parent_iso, "iso_code" => iso}, ids_by_iso) do
    case Map.fetch(ids_by_iso, parent_iso) do
      {:ok, id} -> id
      :error -> Repo.rollback({:missing_parent, iso, parent_iso})
    end
  end

  # A plain attribute map for `Repo.insert_all` (which bypasses the schema's
  # changeset and timestamps, so both are set here). The level FKs default to
  # null — `country_id` is overlaid on subdivisions by the caller.
  defp base_row(row, imported_at) do
    %{
      slug: slug(row["iso_code"]),
      name_en: row["name_en"],
      location_type: String.to_existing_atom(row["type"]),
      iso_code: row["iso_code"],
      is_private: false,
      extras: extras(row, imported_at),
      inserted_at: imported_at,
      updated_at: imported_at
    }
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

  defp missing_url_message do
    """
    ISO 3166 import URL is not configured. Set it before calling import/1:

        config :kjogvi, #{inspect(__MODULE__)}, url: "https://.../iso_3166.jsonl"

    (e.g. the raw URL of a GitHub release asset, via the LOCATIONS_IMPORT_URL
    env var), or pass a URL or local path to import/1 explicitly.
    """
  end
end
