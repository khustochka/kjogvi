defmodule Kjogvi.Legacy.Adapters.Local do
  @moduledoc false

  @per_page 1000

  # Columns joined from ActiveStorage purely to derive a stored image's
  # `original_url` and `meta`; stripped from the row before it is returned.
  @blob_columns ~w(blob_key blob_filename blob_content_type blob_service_name blob_metadata)

  def init() do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: Kjogvi.Legacy.Import.config()[:hostname],
        database: Kjogvi.Legacy.Import.config()[:database],
        port: Kjogvi.Legacy.Import.config()[:port],
        username: Kjogvi.Legacy.Import.config()[:username],
        password: Kjogvi.Legacy.Import.config()[:password]
      )

    pid
  end

  def fetch_page(:locations, pid, page) do
    Postgrex.query!(
      pid,
      "SELECT * FROM loci ORDER BY id LIMIT #{@per_page} OFFSET #{@per_page * (page - 1)}",
      []
    )
  end

  def fetch_page(:checklists, pid, page) do
    Postgrex.query!(
      pid,
      "SELECT * FROM cards ORDER BY id LIMIT #{@per_page} OFFSET #{@per_page * (page - 1)}",
      []
    )
  end

  def fetch_page(:observations, pid, page) do
    Postgrex.query!(
      pid,
      """
      SELECT observations.*, taxa.ebird_code
      FROM observations
      LEFT OUTER JOIN taxa ON taxa.id = taxon_id
      ORDER BY id
      LIMIT #{@per_page}
      OFFSET #{@per_page * (page - 1)}
      """,
      []
    )
  end

  # Legacy images live in the `media` table; photos are `media_type = 'photo'`.
  #
  # In the current DB all images are ActiveStorage-hosted on S3, so the blob is
  # joined in the same query and `original_url`/`meta` are built from it. The
  # blob columns are derivation-only and stripped before the row is returned,
  # leaving `original_url` and `meta` appended (matching the download adapter's
  # shape). `observation_ids` is aggregated from the `media_observations` join.
  # `assets_cache` is ignored.
  def fetch_page(:images, pid, page) do
    result =
      Postgrex.query!(
        pid,
        """
        SELECT
          media.*,
          blobs.key AS blob_key,
          blobs.filename AS blob_filename,
          blobs.content_type AS blob_content_type,
          blobs.service_name AS blob_service_name,
          blobs.metadata AS blob_metadata,
          COALESCE(
            array_agg(media_observations.observation_id)
              FILTER (WHERE media_observations.observation_id IS NOT NULL),
            '{}'
          ) AS observation_ids
        FROM media
        LEFT OUTER JOIN media_observations ON media_observations.media_id = media.id
        LEFT OUTER JOIN active_storage_attachments att
          ON att.record_type = 'Media'
          AND att.record_id = media.id
          AND att.name = 'stored_image'
        LEFT OUTER JOIN active_storage_blobs blobs ON blobs.id = att.blob_id
        WHERE media.media_type = 'photo'
        GROUP BY media.id, blobs.id
        ORDER BY media.id
        LIMIT #{@per_page}
        OFFSET #{@per_page * (page - 1)}
        """,
        []
      )

    derive_image_columns(result)
  end

  # Replaces the derivation-only blob_* columns with computed `original_url` and
  # `meta` columns, so the importer sees the same shape the download adapter
  # returns from the remote API.
  defp derive_image_columns(%Postgrex.Result{columns: columns, rows: rows}) do
    idx = columns |> Enum.with_index() |> Map.new()
    kept = Enum.reject(columns, &(&1 in @blob_columns))
    kept_idx = Enum.map(kept, &Map.fetch!(idx, &1))

    out_rows =
      Enum.map(rows, fn row ->
        get = fn col -> Enum.at(row, Map.fetch!(idx, col)) end
        Enum.map(kept_idx, &Enum.at(row, &1)) ++ [original_url(get), meta(get)]
      end)

    %{columns: kept ++ ["original_url", "meta"], rows: out_rows}
  end

  # Build the public S3 URL from the image's blob key + service bucket.
  defp original_url(get) do
    stored_image_url(get.("blob_service_name"), get.("blob_key"))
  end

  # width/height/exif_date from blob metadata + content_type.
  defp meta(get) do
    metadata = decode_metadata(get.("blob_metadata"))

    %{
      "width" => metadata["width"],
      "height" => metadata["height"],
      "content_type" => get.("blob_content_type"),
      "exif_date" => metadata["exif_date"]
    }
  end

  defp stored_image_url(service_name, key) do
    "https://#{bucket_for(service_name)}.s3.amazonaws.com/#{key}"
  end

  defp bucket_for(service_name) do
    Kjogvi.Legacy.Import.config()
    |> Keyword.get(:image_storage_buckets, %{})
    |> Map.fetch!(service_name)
  end

  defp decode_metadata(nil), do: %{}

  defp decode_metadata(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, map} when is_map(map) -> map
      _ -> %{}
    end
  end

  defp decode_metadata(map) when is_map(map), do: map
end
