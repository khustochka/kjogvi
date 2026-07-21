defmodule Kjogvi.Geo.Restore do
  @moduledoc """
  Restores a curated geo dataset from a CSV snapshot (see `Kjogvi.Geo.Dump`).

  `run/1` reads the snapshot from the configured `Kjogvi.Datasets` storage;
  `from_file/2` takes an explicit path, bypassing the storage config.

  Common locations are upserted **on `id`**: the dump carries each row's
  identity, so `location_id` references, level FKs, and checklist FKs stay
  valid across environments. Existing common rows are refreshed with the
  snapshot's curated columns; user-owned rows are never touched — a snapshot
  id that collides with a user-owned location aborts the whole restore
  (`{:error, {:user_owned_id_collision, ids}}`). The id sequence is bumped
  afterwards so subsequent inserts don't collide with restored ids.

  eBird locations are upserted **on `code`**, replacing every column including
  `location_id` — the snapshot *is* the curated match state. All existing
  links are cleared first: `location_id` is unique, so a link that moved to a
  different `code` since the snapshot's counterpart state would otherwise
  collide mid-upsert. Restore common locations before eBird ones — the links
  reference them.

  Deletions are not propagated: a row dropped from the snapshot stays in the
  DB (same open TODO as `Kjogvi.Geo.Import`).
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.Dump
  alias Kjogvi.Geo.EbirdLocation
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  # Rows carry ~18 fields; keep a batch well under Postgres's 65535
  # bind-parameter limit.
  @chunk_size 3000

  @doc """
  Restores `dataset` from the configured `Kjogvi.Datasets` storage. Returns
  `{:ok, row_count}`.
  """
  def run(dataset) do
    with {:ok, content} <- Datasets.read(Dump.storage_key(dataset)) do
      restore(dataset, content)
    end
  end

  @doc """
  Restores `dataset` from an explicit local `path`, bypassing the storage
  config.
  """
  def from_file(dataset, path) do
    restore(dataset, File.read!(path))
  end

  defp restore(dataset, content) do
    :telemetry.span([:kjogvi, :geo, :restore], %{dataset: dataset}, fn ->
      result = upsert_all(dataset, parse(dataset, content))
      {result, stop_metadata(dataset, result)}
    end)
  end

  defp stop_metadata(dataset, {:ok, count}),
    do: %{dataset: dataset, result: :ok, count: count}

  defp stop_metadata(dataset, {:error, reason}),
    do: %{dataset: dataset, result: :error, reason: reason}

  defp parse(dataset, content) do
    now = DateTime.utc_now()

    content
    |> String.splitter("\n", trim: true)
    |> CSV.decode!(headers: true)
    |> Enum.map(&row_attrs(dataset, &1, now))
  end

  # The dump is ordered parents-first, so inserting in row order satisfies the
  # level FK references within one pass.
  defp upsert_all(:common_locations, rows) do
    Repo.transaction(
      fn ->
        ensure_no_user_owned_collisions(rows)

        count = upsert_chunks(Location, rows, replace_columns(:common_locations), [:id])

        Query.bump_id_sequence()
        count
      end,
      timeout: :infinity
    )
  end

  defp upsert_all(:ebird_locations, rows) do
    Repo.transaction(
      fn ->
        EbirdLocation.Query.matched()
        |> Repo.update_all(set: [location_id: nil])

        upsert_chunks(EbirdLocation, rows, replace_columns(:ebird_locations), [:code])
      end,
      timeout: :infinity
    )
  end

  defp upsert_chunks(schema, rows, replace, conflict_target) do
    rows
    |> Enum.chunk_every(@chunk_size)
    |> Enum.map(fn chunk ->
      {count, _} =
        Repo.insert_all(schema, chunk,
          on_conflict: {:replace, replace},
          conflict_target: conflict_target
        )

      count
    end)
    |> Enum.sum()
  end

  defp ensure_no_user_owned_collisions(rows) do
    collisions =
      Location
      |> Query.by_ids(Enum.map(rows, & &1.id))
      |> Query.only_user_owned()
      |> Query.select_ids()
      |> Repo.all()

    unless Enum.empty?(collisions) do
      Repo.rollback({:user_owned_id_collision, Enum.sort(collisions)})
    end
  end

  # Refresh every dumped column except the conflict key; `inserted_at` (and
  # for common locations `user_id`, nil on every common row) keeps its
  # existing value.
  defp replace_columns(:common_locations) do
    (Dump.columns(:common_locations) -- [:id]) ++ [:updated_at]
  end

  defp replace_columns(:ebird_locations) do
    (Dump.columns(:ebird_locations) -- [:code]) ++ [:updated_at]
  end

  defp row_attrs(:common_locations, row, now) do
    %{
      id: String.to_integer(row["id"]),
      slug: row["slug"],
      name_en: row["name_en"],
      location_type: enum(Location, :location_type, row["location_type"]),
      iso_code: string(row["iso_code"]),
      lat: decimal(row["lat"]),
      lon: decimal(row["lon"]),
      is_private: boolean(row["is_private"]),
      public_index: integer(row["public_index"]),
      import_source: enum(Location, :import_source, row["import_source"]),
      extras: extras(row["extras"]),
      country_id: integer(row["country_id"]),
      subdivision1_id: integer(row["subdivision1_id"]),
      subdivision2_id: integer(row["subdivision2_id"]),
      city_id: integer(row["city_id"]),
      site_id: integer(row["site_id"]),
      inserted_at: now,
      updated_at: now
    }
  end

  defp row_attrs(:ebird_locations, row, now) do
    %{
      code: row["code"],
      location_type: enum(EbirdLocation, :location_type, row["location_type"]),
      country_code: string(row["country_code"]),
      subnational1_code: string(row["subnational1_code"]),
      subnational2_code: string(row["subnational2_code"]),
      name: string(row["name"]),
      location_id: integer(row["location_id"]),
      inserted_at: now,
      updated_at: now
    }
  end

  defp string(""), do: nil
  defp string(value), do: value

  defp integer(""), do: nil
  defp integer(value), do: String.to_integer(value)

  defp decimal(""), do: nil
  defp decimal(value), do: Decimal.new(value)

  defp boolean("true"), do: true
  defp boolean("false"), do: false
  defp boolean(""), do: nil

  # Cast an Ecto.Enum field's stored string back to its atom via the schema's own
  # type, so the valid set stays sourced from the schema and no global atom-table
  # lookup (String.to_existing_atom) is needed — the latter needs the defining
  # module already loaded, which a lean boot can't guarantee.
  defp enum(_schema, _field, ""), do: nil

  defp enum(schema, field, value) do
    {:ok, atom} = Ecto.Type.cast(schema.__schema__(:type, field), value)
    atom
  end

  defp extras(""), do: %{}
  defp extras(value), do: Jason.decode!(value)
end
