defmodule Kjogvi.Ebird.Web.Client do
  @moduledoc """
  HTTP client to query eBird.
  """

  alias Kjogvi.Ebird.Web.Checklist
  alias Kjogvi.Ebird.Web.Client.Login

  @base_url "https://ebird.org"

  def base_url do
    @base_url
  end

  @doc false
  def req do
    Req.new(base_url: @base_url) |> HttpCookie.ReqPlugin.attach()
  end

  @doc """
  Preloads the the most recent checklists metadata.

  * count - the number of checklists
  * start - the index of the first one (1 is the newest).
  """
  def preload_checklists(credentials, start \\ 1, count \\ 100) do
    with {:ok, cookie_jar} <- Login.login(credentials),
         {:ok, resp} <- fetch_checklists_page(cookie_jar, start, count) do
      extract_checklists(resp)
    end
  end

  defp fetch_checklists_page(cookie_jar, start, count) do
    req()
    |> Req.get(
      url: "/mychecklists",
      params: [
        currentRow: start,
        rowsPerPage: count,
        sortBy: "date",
        order: "desc"
      ],
      cookie_jar: cookie_jar
    )
  end

  def extract_checklists(resp) do
    with {:ok, doc} <- Floki.parse_document(resp.body) do
      Floki.find(doc, "ol#place-species-observed-results > li")
      |> Enum.map(fn row ->
        ebird_id =
          Floki.attribute(row, "id")
          # format: "checklist-<checklist_id>"
          |> List.first()
          |> then(&String.slice(&1, 10, String.length(&1) - 10))

        date =
          Floki.find(row, "div.ResultsStats-title > h3 > a > span:nth-child(1)")
          |> Floki.text()
          |> String.trim()
          |> Timex.parse!("{D} {Mshort} {YYYY}")
          |> NaiveDateTime.to_date()

        time =
          Floki.find(row, "div.ResultsStats-title > h3 > a > span:nth-child(2)")
          |> Floki.text()
          |> String.trim()
          |> case do
            "" -> nil
            value -> value |> Timex.parse!("{h12}:{m} {AM}") |> NaiveDateTime.to_time()
          end

        location =
          Floki.find(
            row,
            "div.ResultsStats-details > div.u-showForMedium > div > div:nth-child(1) > div.ResultsStats-details-location"
          )
          |> Floki.text()
          |> String.trim()
          |> space_to_nil()

        county =
          Floki.find(
            row,
            "div.ResultsStats-details > div.u-showForMedium > div > div:nth-child(2) > div.ResultsStats-details-county"
          )
          |> Floki.text()
          |> String.trim()
          |> space_to_nil()

        region =
          Floki.find(
            row,
            "div.ResultsStats-details > div.u-showForMedium > div > div:nth-child(3) > div.ResultsStats-details-stateCountry"
          )
          |> Floki.text()
          |> String.trim()
          |> space_to_nil()

        country =
          Floki.find(
            row,
            "div.ResultsStats-details > div.u-showForMedium > div > div:nth-child(4) > div.ResultsStats-details-stateCountry"
          )
          |> Floki.text()
          |> String.trim()
          |> space_to_nil()

        %Checklist.Meta{
          ebird_id: ebird_id,
          date: date,
          time: time,
          location: location,
          county: county,
          region: region,
          country: country
        }
      end)
      |> then(&{:ok, &1})
    end
  end

  defp space_to_nil(""), do: nil
  defp space_to_nil(str), do: str
end
