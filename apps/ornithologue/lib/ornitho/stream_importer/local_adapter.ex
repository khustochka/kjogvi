defmodule Ornitho.StreamImporter.LocalAdapter do
  @moduledoc """
  Adapter for taxonomy importer that load source files from disk.
  """

  def file_streamer(%{path_prefix: path_prefix}, path) do
    Path.join(path_prefix, path) |> File.stream!([:trim_bom])
  end

  def validate_config do
    {:ok, %{path_prefix: path_prefix()}}
  end

  # Defaults to the app's priv directory, resolved to an absolute path so imports
  # do not depend on the server's current working directory (which can differ
  # across restarts or in a release).
  defp path_prefix do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)[:path_prefix] ||
      Application.app_dir(:ornithologue, "priv")
  end
end
