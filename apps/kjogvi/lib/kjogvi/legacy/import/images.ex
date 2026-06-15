defmodule Kjogvi.Legacy.Import.Images do
  @moduledoc """
  Legacy images import.

  Each legacy `media` photo row is mapped onto a `Kjogvi.Images.Image`.
  Unmatched columns, the legacy `title` (as `legacy_title`), and the derived `meta`
  (width, height, content_type, exif_date) go into `extras`; `original_url` becomes
  `legacy_url`.

  Legacy ids are preserved on import, so each row's `observation_ids` (aggregated
  by the adapters) rebuilds `ImageObservation` join rows straight through.
  """

  alias Kjogvi.Legacy.Import.Utils
  alias Kjogvi.Repo
  alias Kjogvi.Images.Image
  alias Kjogvi.Images.ImageObservation

  @min_start_seq 10_000

  # Legacy `media` columns moved verbatim into `extras` (under string keys), in
  # addition to `title` -> `extras["legacy_title"]` handled below.
  @extra_columns [:assets_cache, :external_id, :spot_id, :status]

  def import(columns_str, rows, opts) do
    columns = columns_str |> Enum.map(&String.to_atom/1)
    user = user!(opts)
    time = DateTime.utc_now()

    media =
      for row <- rows do
        columns |> Enum.zip(row) |> Map.new()
      end

    images = Enum.map(media, &transform(&1, user))
    joins = Enum.flat_map(media, &observation_joins(&1, time))

    with {_, _} <- Repo.insert_all(Image, images),
         {_, _} <- Repo.insert_all(ImageObservation, joins),
         {:ok, _} <-
           Repo.query(
             "SELECT setval('images_id_seq', GREATEST(#{@min_start_seq}, (SELECT COALESCE(MAX(id), 0) FROM images)));"
           ) do
      :ok
    end
  end

  def after_import do
    :ok
  end

  @doc """
  Removes previously imported legacy images so the import is idempotent.

  Deletes the join rows for legacy images first, then the image rows themselves.
  """
  def cleanup do
    with {:ok, _} <-
           Kjogvi.Repo.query("""
           DELETE FROM image_observations
           USING images
           WHERE image_observations.image_id = images.id
             AND images.import_source = 'legacy';
           """) do
      Kjogvi.Repo.query("DELETE FROM images WHERE import_source='legacy';")
    end
  end

  defp transform(%{id: id, slug: slug} = media, user) do
    %{
      id: id,
      slug: slug,
      title: nil,
      description: Utils.blank_to_nil(media[:description]),
      sort_order: media[:index_num],
      multi_species: media[:multi_species] || false,
      extras: extras(media),
      legacy_url: media[:original_url],
      user_id: user.id,
      token: Kjogvi.Util.Token.generate(),
      storage_backend: "legacy",
      import_source: :legacy,
      inserted_at: Utils.convert_timestamp(media[:created_at]),
      updated_at: Utils.convert_timestamp(media[:updated_at])
    }
  end

  defp observation_joins(%{id: media_id} = media, time) do
    media
    |> Map.get(:observation_ids)
    |> List.wrap()
    |> Enum.map(fn observation_id ->
      %{
        image_id: media_id,
        observation_id: observation_id,
        inserted_at: time,
        updated_at: time
      }
    end)
  end

  # Keys lifted from the legacy `meta` map into `extras` under the same names,
  # matching what the upload path stores (see Kjogvi.Images.VixProcessor).
  @meta_keys ~w(width height content_type exif_date)

  defp extras(media) do
    @extra_columns
    |> Enum.reduce(%{}, fn key, acc ->
      put_extra(acc, Atom.to_string(key), media[key])
    end)
    |> put_legacy_title(media[:title])
    |> put_meta(media[:meta])
  end

  # Copies the `@meta_keys` from the legacy `meta` into extras under matching
  # string keys.
  #
  # Map clause: `meta` is already a string-keyed map (the local adapter returns
  # decoded jsonb). Binary clause: `meta` is a JSON string (the download adapter
  # passes it through verbatim), decoded and retried. Final clause tolerates a
  # missing or malformed `meta`.
  defp put_meta(extras, meta) when is_map(meta) do
    Enum.reduce(@meta_keys, extras, fn key, acc ->
      put_extra(acc, key, meta[key])
    end)
  end

  defp put_meta(extras, meta) when is_binary(meta) do
    case Jason.decode(meta) do
      {:ok, decoded} -> put_meta(extras, decoded)
      _ -> extras
    end
  end

  defp put_meta(extras, _meta), do: extras

  # Drop nils so legacy-absent columns don't litter `extras` with null values.
  defp put_extra(extras, _key, nil), do: extras
  defp put_extra(extras, key, value), do: Map.put(extras, key, value)

  # The legacy `title` is often a blank/whitespace-only string rather than NULL;
  # skip those so `extras` only carries a meaningful `legacy_title`.
  defp put_legacy_title(extras, title) do
    case Utils.blank_to_nil(title) do
      nil -> extras
      trimmed -> Map.put(extras, "legacy_title", trimmed)
    end
  end

  defp user!(opts) do
    case Keyword.get(opts, :user) do
      %{id: id} = user when not is_nil(id) -> user
      _ -> raise ArgumentError, "Legacy import requires a :user option"
    end
  end
end
