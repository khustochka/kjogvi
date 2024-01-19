defmodule Ornitho.StreamImporter.LocalAdapter do
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
