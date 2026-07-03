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

  @impl true
  def last_modified(config, key) do
    bucket!(config)
    |> ExAws.S3.head_object(key)
    |> ExAws.request(request_overrides(config))
    |> case do
      {:ok, %{headers: headers}} -> last_modified_header(headers)
      {:error, _} = error -> error
    end
  end

  defp last_modified_header(headers) do
    case Enum.find(headers, fn {name, _} -> String.downcase(name) == "last-modified" end) do
      {_, value} -> parse_http_date(value)
      nil -> {:error, :no_last_modified_header}
    end
  end

  @months %{
    "Jan" => 1,
    "Feb" => 2,
    "Mar" => 3,
    "Apr" => 4,
    "May" => 5,
    "Jun" => 6,
    "Jul" => 7,
    "Aug" => 8,
    "Sep" => 9,
    "Oct" => 10,
    "Nov" => 11,
    "Dec" => 12
  }

  @doc false
  # RFC 7231 HTTP date, e.g. "Wed, 12 Oct 2009 17:50:00 GMT".
  def parse_http_date(value) do
    with [_weekday, day, month_name, year, time, "GMT"] <- String.split(value, [", ", " "]),
         {:ok, month} <- Map.fetch(@months, month_name),
         {day, ""} <- Integer.parse(day),
         {year, ""} <- Integer.parse(year),
         {:ok, time} <- Time.from_iso8601(time),
         {:ok, date} <- Date.new(year, month, day) do
      DateTime.new(date, time, "Etc/UTC")
    else
      _ -> {:error, {:invalid_http_date, value}}
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
