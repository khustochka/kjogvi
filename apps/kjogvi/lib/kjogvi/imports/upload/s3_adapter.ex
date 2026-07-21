defmodule Kjogvi.Imports.Upload.S3Adapter do
  @moduledoc """
  Stores import uploads on S3 (`:bucket`, `:region`), in a dedicated bucket
  kept separate from image storage so a lifecycle rule can expire abandoned
  uploads on its own schedule.

  Wired only in production (`runtime.exs`), via the `KJOGVI_EBIRD_UPLOADS_*`
  env vars.
  """

  @behaviour Kjogvi.Imports.Upload.Adapter

  @impl true
  def configured?(config) do
    config[:bucket] not in [nil, ""]
  end

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
  def fetch_to(config, key, local_path) do
    bucket!(config)
    |> ExAws.S3.download_file(key, local_path)
    |> ExAws.request(request_overrides(config))
    |> case do
      {:ok, _} -> :ok
      {:error, _} = error -> error
    end
  end

  @impl true
  def delete(config, key) do
    bucket!(config)
    |> ExAws.S3.delete_object(key)
    |> ExAws.request(request_overrides(config))
    |> case do
      {:ok, _} -> :ok
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
