defmodule Kjogvi.Geo.Import do
  @moduledoc """
  Import of ISO 3166-1 (countries/territories) and ISO 3166-2 (subdivisions)
  into `Kjogvi.Geo.Location` as `country` and `subdivision1` locations.

  Reads a pre-built JSONL file (see `priv/geo/build_iso_3166.exs`), one location
  per line. The data is strictly two-level — countries, then their subdivisions —
  so it is bulk-inserted with `Repo.insert_all` in two passes (countries first,
  then subdivisions with `country_id` taken from the countries just upserted)
  rather than one changeset per row, keeping the whole import well under a second.

  The single entry point is `import/2`, which dispatches on its source: an
  `http(s)://` URL is fetched over HTTP, any other string is a local file path,
  and the default is the configured URL (`default_url/0`, never hardcoded). The
  generated data is hosted out-of-band (e.g. a GitHub release asset) rather than
  committed, so a fresh deployment can fill an empty `locations` table from the
  configured URL without a shell or the `iso-codes` package on the host.

  The dataset is small (a few hundred KB), so the HTTP body is buffered whole
  rather than streamed end-to-end; only the local-file path streams from disk.

  ## Re-runnable upsert

  The import upserts on `iso_code`: a row already present (same `iso_code`) is
  updated rather than skipped or duplicated, so it can be re-run against a newer
  iso-codes release. The conflict update refreshes only the ISO-sourced columns
  (`name_en`, `extras`, `import_source`, `updated_at`, and a subdivision's
  `country_id`) and
  leaves each row's `id` intact (checklists reference locations by id). Columns a user
  may have edited locally — `slug`, `is_private`, `lat`, `lon` — are *not*
  overwritten on conflict.

  TODO: it still does not reconcile *removals* — a subdivision that disappears
  from a newer ISO release stays in the table (it may carry checklists). Pruning such
  orphans is left to a future pass.
  """

  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

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
  Whether any `country` location already exists.
  """
  def country_exists? do
    Location
    |> Query.countries()
    |> Repo.exists?()
  end

  defp run(lines) do
    :telemetry.span([:kjogvi, :geo, :import], %{}, fn ->
      result = upsert_all(lines)
      {result, stop_metadata(result)}
    end)
  end

  defp stop_metadata({:ok, ids_by_iso}), do: %{result: :ok, count: map_size(ids_by_iso)}
  defp stop_metadata({:error, reason}), do: %{result: :error, reason: reason}

  # Two passes (the data is strictly two-level): countries first, then
  # subdivisions whose `country_id` comes from the countries' resolved ids.
  # Returns a `%{iso_code => id}` map.
  defp upsert_all(lines) do
    imported_at = DateTime.utc_now()
    parsed = Enum.map(lines, &Jason.decode!/1)
    {countries, subdivisions} = Enum.split_with(parsed, &(&1["parent_iso"] == nil))

    Repo.transaction(
      fn ->
        # Bump before inserting so imported rows take ids in the reserved upper
        # range without colliding with any existing row.
        Query.bump_id_sequence()
        ids_by_iso = insert_countries(countries, imported_at)
        insert_subdivisions(subdivisions, ids_by_iso, imported_at)
      end,
      timeout: :infinity
    )
  end

  defp insert_countries(countries, imported_at) do
    rows = Enum.map(countries, &base_row(&1, imported_at))

    # `DO UPDATE` (not `DO NOTHING`) also returns existing rows, so the id map
    # stays complete on a re-run for subdivisions to resolve `country_id`.
    {_, upserted} =
      Repo.insert_all(Location, rows,
        on_conflict: on_conflict(),
        conflict_target: conflict_target(),
        returning: [:id, :iso_code]
      )

    Map.new(upserted, &{&1.iso_code, &1.id})
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
    |> Enum.each(
      &Repo.insert_all(Location, &1,
        on_conflict: on_conflict(),
        conflict_target: conflict_target()
      )
    )

    Map.merge(ids_by_iso, Map.new(rows, &{&1.iso_code, nil}))
  end

  # Refresh only ISO-sourced columns; leave user-editable ones (`slug`,
  # `is_private`, `lat`, `lon`) and `id`/`inserted_at` untouched.
  defp on_conflict do
    {:replace, [:name_en, :country_id, :extras, :import_source, :updated_at]}
  end

  # The `iso_code` unique index is partial, so the conflict target must repeat
  # its predicate for Postgres to infer it.
  defp conflict_target do
    {:unsafe_fragment, "(iso_code) WHERE iso_code IS NOT NULL"}
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
      import_source: :iso,
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
