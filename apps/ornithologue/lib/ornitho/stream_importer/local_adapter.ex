defmodule Ornitho.StreamImporter.LocalAdapter do
  @moduledoc """
  Adapter for taxonomy importer that load source files from disk.
  """

  @default_path_prefix "priv"

  def file_streamer(path) do
    Path.join(path_prefix(), path)
    |> File.stream!([:trim_bom])
  end

  defp path_prefix do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)[:path_prefix] ||
      @default_path_prefix
  end
end
