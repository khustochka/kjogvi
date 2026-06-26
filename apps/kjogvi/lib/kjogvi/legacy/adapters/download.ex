defmodule Kjogvi.Legacy.Adapters.Download do
  @moduledoc false

  @per_page 2_000

  @required_config [url: "LEGACY_URL", api_key: "LEGACY_API_KEY"]

  @doc """
  Checks that the remote URL and API key are configured, returning a friendly
  `{:error, %{message: ...}}` when one is missing so the import can fail cleanly
  before issuing any request. Called by `Kjogvi.Legacy.Import.run/2`.
  """
  def validate_config do
    missing =
      for {key, env_var} <- @required_config, !configured?(key), do: env_var

    case missing do
      [] ->
        :ok

      env_vars ->
        {:error,
         %{
           message:
             "Legacy import (download) is not configured. " <>
               "Set #{Enum.join(env_vars, " and ")} before running the import."
         }}
    end
  end

  def init() do
    Req.new(base_url: require_config!(:url, "LEGACY_URL"), auth: auth())
    |> OpentelemetryReq.attach()
    |> Req.Request.put_header("accept", "application/json")
  end

  def fetch_page(:locations, req, page) do
    req
    |> Req.get!(url: "loci?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  def fetch_page(:checklists, req, page) do
    req
    |> Req.get!(url: "cards?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  def fetch_page(:observations, req, page) do
    req
    |> Req.get!(url: "observations?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  def fetch_page(:images, req, page) do
    req
    |> Req.get!(url: "images?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  defp convert_body(%Req.Response{body: %{"columns" => columns, "rows" => rows}}) do
    %{columns: columns, rows: rows}
  end

  defp auth do
    {:bearer, require_config!(:api_key, "LEGACY_API_KEY")}
  end

  defp configured?(key) do
    case Kjogvi.Legacy.Import.config()[key] do
      value when is_binary(value) and value != "" -> true
      _ -> false
    end
  end

  # Reads a required config value, raising a clear message (rather than letting a
  # nil surface as an opaque Req error deep in the request) when it is missing.
  # This is the last-resort guard; `validate_config/0` normally catches the same
  # gap earlier and turns it into a friendly `{:error, _}`.
  defp require_config!(key, env_var) do
    if configured?(key) do
      Kjogvi.Legacy.Import.config()[key]
    else
      raise """
      Legacy import (download adapter) is not configured: #{key} is missing.
      Set the #{env_var} environment variable (see config/dev.exs).
      """
    end
  end
end
