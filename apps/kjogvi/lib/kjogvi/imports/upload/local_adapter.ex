defmodule Kjogvi.Imports.Upload.LocalAdapter do
  @moduledoc """
  Stores import uploads as plain files under the configured `:path` directory.
  The default adapter — dev and test round-trip local files and never touch
  the prod upload bucket.

  `:path` is used as-is. It should be **absolute**: the writer (a LiveView in
  one umbrella app) and the reader (an Oban job in another) run with different
  working directories, so a relative path would resolve to different places and
  the job would miss the file. The base config anchors it to the umbrella root.
  Unlike `Kjogvi.Datasets.LocalAdapter` these files are throwaway, so there is no
  `:otp_app`/priv resolution — a scratch dir is exactly what's wanted.
  """

  @behaviour Kjogvi.Imports.Upload.Adapter

  @impl true
  def configured?(config) do
    config[:path] not in [nil, ""]
  end

  @impl true
  def write(config, key, content) do
    path = full_path(config, key)

    with :ok <- File.mkdir_p(Path.dirname(path)) do
      File.write(path, content)
    end
  end

  @impl true
  def fetch_to(config, key, local_path) do
    File.cp(full_path(config, key), local_path)
  end

  @impl true
  def delete(config, key) do
    case File.rm(full_path(config, key)) do
      {:error, :enoent} -> :ok
      other -> other
    end
  end

  defp full_path(config, key) do
    Path.join(Keyword.fetch!(config, :path), key)
  end
end
