defmodule Kjogvi.Legacy.Adapters.Download do
  @moduledoc false

  @per_page 1000

  def init() do
    Req.new(base_url: base_url(), auth: auth())
    |> Req.Request.put_header("accept", "application/json")
  end

  def fetch_page(:locations, req, page) do
    req
    |> Req.get!(url: "loci?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  def fetch_page(:cards, req, page) do
    req
    |> Req.get!(url: "cards?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  def fetch_page(:observations, req, page) do
    req
    |> Req.get!(url: "observations?page=#{page}&per_page=#{@per_page}")
    |> convert_body
  end

  defp convert_body(%Req.Response{body: []}) do
    %{columns: [], rows: []}
  end

  defp convert_body(%Req.Response{body: [fst | _] = body}) do
    %{columns: Map.keys(fst), rows: Enum.map(body, &Map.values/1)}
  end

  defp base_url do
    Kjogvi.Legacy.Import.config()[:url]
  end

  defp auth do
    {:bearer, Kjogvi.Legacy.Import.config()[:api_key]}
  end
end
