defmodule Kjogvi.Datasets.S3Adapter do
  @moduledoc """
  Stores dataset snapshots on S3 (`:bucket`, `:region`). Keys are fixed —
  snapshot history comes from bucket versioning, not timestamped keys.

  Wired only in production (`runtime.exs`), via the `KJOGVI_DATASETS_*` env
  vars.
  """

  @behaviour Kjogvi.Datasets.Adapter

  @impl true
  def write(config, key, content) do
    bucket!(config)
    |> ExAws.S3.put_object(key, IO.iodata_to_binary(content))
    |> ExAws.request(request_overrides(config))
    |> case do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def read(config, key) do
    bucket!(config)
    |> ExAws.S3.get_object(key)
    |> ExAws.request(request_overrides(config))
    |> case do
      {:ok, %{body: body}} -> {:ok, body}
      {:error, _} = error -> error
    end
  end

  # Credentials are optional: absent ones are omitted so ex_aws falls back to
  # the global config chain (the image storage profile / instance role).
  defp request_overrides(config) do
    [:access_key_id, :secret_access_key]
    |> Enum.reduce([region: config[:region]], fn key, acc ->
      case config[key] do
        value when value in [nil, ""] -> acc
        value -> [{key, value} | acc]
      end
    end)
  end

  defp bucket!(config) do
    Keyword.fetch!(config, :bucket)
  end
end
