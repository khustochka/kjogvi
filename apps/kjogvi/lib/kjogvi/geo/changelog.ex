defmodule Kjogvi.Geo.Changelog do
  @moduledoc """
  Reapplies curated edits to common locations on top of a raw ISO 3166 import.

  `Kjogvi.Geo.Import` deliberately refreshes only ISO-sourced columns and
  leaves the curated ones alone, so a raw import (or a newer ISO release)
  arrives with none of the hand-made decisions this project has accumulated:
  territories that duplicate a country entry are `disabled`, a couple of
  countries carry `hide_flag`, and some `name_en`s are the common short form
  rather than ISO's formal one ("Bolivia", not "Bolivia, Plurinational State
  of"). This module carries those edits back.

  Reads a JSONL changelog, one op per line, addressed by `iso_code`:

      {"iso_code":"BO","op":"update","fields":{"name_en":"Bolivia"}}
      {"iso_code":"US-PR","op":"update","fields":{"disabled":true},
       "note":"Puerto Rico; PR country instead"}

  `op` is `"update"` (the only op today); `fields` may set any of
  `name_en`, `disabled`, `hide_flag`; `note` is free-text provenance for a
  human reader and is not applied.

  The source file lives in the `Kjogvi.Datasets` snapshot storage under
  `source_key/0` (`geo/sources/iso_locations_changelog.jsonl`) — local files
  in dev/test, S3 in prod — and is *read-only* from the app's side: it is
  hand-curated and uploaded to the storage out-of-band, never written by the
  app. `apply/0` reads it from there (the admin imports card); `from_jsonl/1`
  takes an explicit local path, bypassing the storage config (bootstrap
  scripts, tests).

  ## Re-runnable

  Every op is an idempotent absolute set (`disabled: true`, `name_en:
  "Bolivia"`) keyed on `iso_code`, so applying twice is a no-op and applying
  after a fresh import restores the same curated state. An `iso_code` matching
  no location is skipped and reported rather than failing the run — the
  changelog outlives any single ISO release, and some codes it names only
  exist once other imports have run.
  """

  alias Kjogvi.Datasets
  alias Kjogvi.Geo.Location
  alias Kjogvi.Geo.Location.Query
  alias Kjogvi.Repo

  @source_key "geo/sources/iso_locations_changelog.jsonl"

  @updatable_fields ~w(name_en disabled hide_flag)

  @doc """
  The changelog's fixed key in the `Kjogvi.Datasets` storage.
  """
  def source_key, do: @source_key

  @doc """
  Applies the changelog read from the configured `Kjogvi.Datasets` storage
  (`source_key/0`). `{:error, :enoent}` when no changelog has been uploaded
  yet; `{:ok, %{count: n, skipped: [iso_code, ...]}}` on success.
  """
  def apply do
    with {:ok, body} <- Datasets.read(@source_key) do
      body
      |> decode_jsonl()
      |> run()
    end
  end

  @doc """
  Applies the changelog from an explicit local `path`, bypassing the storage
  config. Returns `{:ok, %{count: n, skipped: [iso_code, ...]}}`.
  """
  def from_jsonl(path) when is_binary(path) do
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

  defp run(ops) do
    :telemetry.span([:kjogvi, :geo, :changelog, :apply], %{}, fn ->
      result = apply_all(ops)
      {result, stop_metadata(result)}
    end)
  end

  defp stop_metadata({:ok, %{count: count, skipped: skipped}}),
    do: %{result: :ok, count: count, skipped: skipped}

  defp stop_metadata({:error, reason}), do: %{result: :error, reason: reason}

  # One statement per op: the ops are few (tens) and each targets a single row
  # by `iso_code`, so there is nothing to gain from batching them.
  defp apply_all(ops) do
    Repo.transaction(fn ->
      {applied, skipped} =
        Enum.reduce(ops, {0, []}, fn op, {applied, skipped} ->
          case apply_op(op) do
            :ok -> {applied + 1, skipped}
            {:skipped, iso_code} -> {applied, [iso_code | skipped]}
          end
        end)

      %{count: applied, skipped: Enum.reverse(skipped)}
    end)
  end

  defp apply_op(%{"iso_code" => iso_code, "op" => "update", "fields" => fields}) do
    changes = updates(fields)

    {count, _} =
      Location
      |> Query.by_iso_code(iso_code)
      |> Repo.update_all(set: changes ++ [updated_at: DateTime.utc_now()])

    case count do
      0 -> {:skipped, iso_code}
      _ -> :ok
    end
  end

  # Unknown keys in `fields` are a curation mistake worth surfacing loudly
  # rather than silently dropping.
  defp updates(fields) do
    Enum.map(fields, fn {field, value} ->
      unless field in @updatable_fields do
        raise ArgumentError,
              "changelog cannot update #{inspect(field)}; allowed: #{inspect(@updatable_fields)}"
      end

      {String.to_existing_atom(field), value}
    end)
  end
end
