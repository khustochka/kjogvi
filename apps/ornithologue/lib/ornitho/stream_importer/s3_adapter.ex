defmodule Ornitho.StreamImporter.S3Adapter do
  @moduledoc """
  Adapter for taxonomy importer that downloads source files from S3.
  """

  def file_streamer(%{bucket: bucket, region: region} = _config, path) do
    with {:ok, resp} <- ExAws.S3.get_object(bucket, path) |> ExAws.request(region: region),
         {:ok, stream} <- resp[:body] |> StringIO.open() do
      stream
      |> IO.binstream(:line)
    end
  end

  def validate_config do
    [:bucket, :region]
    |> Enum.reduce({%{}, []}, fn key, {output, errors} ->
      value = config()[key]

      if value in [nil, ""] do
        {output, ["#{key} is not configured" | errors]}
      else
        {Map.put(output, key, value), errors}
      end
    end)
    |> case do
      {configs, []} -> {:ok, configs}
      {_, errors} -> {:error, "Ornitho.StreamImporter.S3Adapter: #{Enum.join(errors, ", ")}."}
    end
  end

  defp config do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)
  end
end
