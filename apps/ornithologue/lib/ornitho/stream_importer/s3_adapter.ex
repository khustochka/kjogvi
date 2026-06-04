defmodule Ornitho.StreamImporter.S3Adapter do
  @moduledoc """
  Adapter for taxonomy importer that downloads source files from S3.
  """

  def file_streamer(%{bucket: bucket} = config, path) do
    overrides = request_overrides(config)

    with {:ok, resp} <- ExAws.S3.get_object(bucket, path) |> ExAws.request(overrides),
         {:ok, stream} <- resp[:body] |> StringIO.open() do
      stream
      |> IO.binstream(:line)
    end
  end

  @doc """
  Per-request ex_aws overrides for the taxonomy profile.

  Credentials are optional: when unset, they are omitted so ex_aws falls back to
  the global config chain (the image storage profile / instance role). Region is
  always passed since `validate_config/0` requires it.
  """
  def request_overrides(config) do
    [:access_key_id, :secret_access_key]
    |> Enum.reduce([region: config[:region]], fn key, acc ->
      case config[key] do
        value when value in [nil, ""] -> acc
        value -> [{key, value} | acc]
      end
    end)
  end

  @required_keys [:bucket, :region]
  @optional_keys [:access_key_id, :secret_access_key]

  def validate_config do
    @required_keys
    |> Enum.reduce({%{}, []}, fn key, {output, errors} ->
      value = config()[key]

      if value in [nil, ""] do
        {output, ["#{key} is not configured" | errors]}
      else
        {Map.put(output, key, value), errors}
      end
    end)
    |> case do
      {configs, []} -> {:ok, Map.merge(configs, optional_config())}
      {_, errors} -> {:error, "Ornitho.StreamImporter.S3Adapter: #{Enum.join(errors, ", ")}."}
    end
  end

  # Optional credentials carried through to the request override. Absent ones
  # are dropped so ex_aws falls back to the global config chain.
  defp optional_config do
    @optional_keys
    |> Enum.flat_map(fn key ->
      case config()[key] do
        value when value in [nil, ""] -> []
        value -> [{key, value}]
      end
    end)
    |> Map.new()
  end

  defp config do
    Application.get_env(:ornithologue, Ornitho.StreamImporter)
  end
end
