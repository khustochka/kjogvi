defmodule Ornitho.StreamImporter.S3Adapter do
  @moduledoc """
  Adapter for taxonomy importer that downloads source files from S3.
  """

  def file_streamer(path) do
    resp =
      ExAws.S3.get_object(bucket(), path)
      |> ExAws.request!(region: region())

    {:ok, stream} =
      resp[:body]
      |> StringIO.open()

    stream
    |> IO.binstream(:line)
  end

  defp bucket do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)[:bucket]
  end

  defp region do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)[:region]
  end
end
