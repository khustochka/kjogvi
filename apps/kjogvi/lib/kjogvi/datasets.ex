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

  defp adapter do
    Keyword.fetch!(config(), :adapter)
  end

  defp config do
    Application.get_env(:kjogvi, __MODULE__, [])
  end
end
