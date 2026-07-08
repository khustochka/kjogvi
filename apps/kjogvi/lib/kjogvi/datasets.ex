defmodule Kjogvi.Datasets do
  @moduledoc """
  Snapshot storage for curated datasets, behind a configurable adapter.

  Not tied to any particular dataset: callers address snapshots by key (e.g.
  `"geo/common_locations.csv"`) and the adapter maps keys to its backing store.
  The base config uses `Kjogvi.Datasets.LocalAdapter` (files under a local
  directory); production switches to `Kjogvi.Datasets.S3Adapter` in
  `runtime.exs`, so dev and test never see the prod snapshots by accident.

      config :kjogvi, Kjogvi.Datasets,
        adapter: Kjogvi.Datasets.LocalAdapter,
        path: "priv/datasets"
  """

  @doc """
  Whether the configured adapter has the settings it needs to reach its
  backing store (e.g. the S3 adapter's bucket).
  """
  def configured? do
    adapter().configured?(config())
  end

  def write(key, content) do
    adapter().write(config(), key, content)
  end

  def read(key) do
    adapter().read(config(), key)
  end

  @doc """
  When the snapshot under `key` was last written (UTC). `{:error, :enoent}`
  when no snapshot exists yet.
  """
  def last_modified(key) do
    adapter().last_modified(config(), key)
  end

  @doc """
  What is known about the snapshot under `key`: `{:ok, modified_at}`, `:none`
  (storage reachable, no snapshot yet), `:not_configured`, or
  `{:error, reason}` when the storage check itself failed. Never raises, so
  UI code can render a notice instead of crashing on broken storage.
  """
  def snapshot_status(key) do
    if configured?() do
      check_snapshot(key)
    else
      :not_configured
    end
  end

  defp check_snapshot(key) do
    case last_modified(key) do
      {:ok, modified_at} -> {:ok, modified_at}
      {:error, :enoent} -> :none
      {:error, reason} -> {:error, reason}
    end
  rescue
    error -> {:error, error}
  end

  defp adapter do
    Keyword.fetch!(config(), :adapter)
  end

  defp config do
    Application.get_env(:kjogvi, __MODULE__, [])
  end
end
