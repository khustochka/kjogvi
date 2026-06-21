defmodule Kjogvi.Geo.Import do
  @moduledoc """
  One-shot import of ISO 3166-1 (countries/territories) and ISO 3166-2
  (subdivisions) into `Kjogvi.Geo.Location` as `country` and `subdivision1`
  locations.

  Reads a pre-built JSONL file (see `priv/geo/build_iso_3166.exs`), one location
  per line, parents before children. Each row is inserted through
  `Location.changeset/2` with the parent's id as the virtual `parent_id`, so the
  level FK columns (`country_id` …) are derived from the parent.

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
  defp run(lines) do
    if country_exists?() do
      {:error, :already_imported}
    else
      insert_all(lines)
    end
  end

  defp insert_all(lines) do
    imported_at = DateTime.utc_now()

    Repo.transaction(
      fn ->
        lines
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

  defp missing_url_message do
    """
    ISO 3166 import URL is not configured. Set it before calling import/1:

        config :kjogvi, #{inspect(__MODULE__)}, url: "https://.../iso_3166.jsonl"

    (e.g. the raw URL of a GitHub release asset, via the LOCATIONS_IMPORT_URL
    env var), or pass a URL or local path to import/1 explicitly.
    """
  end
end
