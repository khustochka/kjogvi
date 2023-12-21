defmodule KjogviWeb.Live.Lifelist.Params do
  @moduledoc """
  Normalizing parameters for Lifelist controller.
  """

  import Ecto.Query

  def to_filter(%{"year_or_location" => year_or_location}) do
    if year_or_location =~ ~r/\A\d{4}\Z/ do
      %{year: String.to_integer(year_or_location)}
    else
      %{location: validate_and_convert_location(year_or_location)}
    end
  end

  def to_filter(params) do
    Enum.reduce(params, %{}, fn el, acc ->
      case el do
        {"year", year} ->
          Map.put(acc, :year, validate_and_convert_year(year))

        {"location", location_slug} ->
          Map.put(acc, :location, validate_and_convert_location(location_slug))
      end
    end)
  end

  defp validate_and_convert_location(location_slug) do
    from(Kjogvi.Geo.Location)
    |> where(slug: ^location_slug)
    |> Kjogvi.Repo.one!()
  end

  defp validate_and_convert_year(year) do
    String.to_integer(year)
  end
end
