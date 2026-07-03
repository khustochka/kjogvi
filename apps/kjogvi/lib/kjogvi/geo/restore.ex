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

  Deletions are not propagated: a row dropped from the snapshot stays in the
  DB (same open TODO as `Kjogvi.Geo.Import`).
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.Dump
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

  defp restore(:common_locations = dataset, content) do
    :telemetry.span([:kjogvi, :geo, :restore], %{dataset: dataset}, fn ->
      result = upsert_all(parse(content))
      {result, stop_metadata(dataset, result)}
    end)
  end

  defp stop_metadata(dataset, {:ok, count}),
    do: %{dataset: dataset, result: :ok, count: count}

  defp stop_metadata(dataset, {:error, reason}),
    do: %{dataset: dataset, result: :error, reason: reason}

  defp parse(content) do
    now = DateTime.utc_now()

    content
    |> String.splitter("\n", trim: true)
    |> CSV.decode!(headers: true)
    |> Enum.map(&row_attrs(&1, now))
  end

  # The dump is ordered parents-first, so inserting in row order satisfies the
  # level FK references within one pass.
  defp upsert_all(rows) do
    Repo.transaction(
      fn ->
        ensure_no_user_owned_collisions(rows)

        count =
          rows
          |> Enum.chunk_every(@chunk_size)
          |> Enum.map(&upsert_chunk/1)
          |> Enum.sum()

        Query.bump_id_sequence()
        count
      end,
      timeout: :infinity
    )
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

  defp upsert_chunk(rows) do
    {count, _} =
      Repo.insert_all(Location, rows,
        on_conflict: {:replace, replace_columns()},
        conflict_target: [:id]
      )

    count
  end

  # Refresh every dumped column except the conflict key; `inserted_at` and
  # `user_id` (nil on every common row) keep their existing values.
  defp replace_columns do
    (Dump.columns() -- [:id]) ++ [:updated_at]
  end

  defp row_attrs(row, now) do
    %{
      id: String.to_integer(row["id"]),
      slug: row["slug"],
      name_en: row["name_en"],
      location_type: String.to_existing_atom(row["location_type"]),
      iso_code: string(row["iso_code"]),
      lat: decimal(row["lat"]),
      lon: decimal(row["lon"]),
      is_private: boolean(row["is_private"]),
      public_index: integer(row["public_index"]),
      import_source: atom(row["import_source"]),
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

  defp string(""), do: nil
  defp string(value), do: value

  defp integer(""), do: nil
  defp integer(value), do: String.to_integer(value)

  defp decimal(""), do: nil
  defp decimal(value), do: Decimal.new(value)

  defp boolean("true"), do: true
  defp boolean("false"), do: false
  defp boolean(""), do: nil

  defp atom(""), do: nil
  defp atom(value), do: String.to_existing_atom(value)

  defp extras(""), do: %{}
  defp extras(value), do: Jason.decode!(value)
end
