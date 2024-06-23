defmodule KjogviWeb.Live.Lifelist.Params do
  @moduledoc """
  Normalizing parameters for Lifelist controller.
  """

  alias Kjogvi.Birding

  def to_filter(params) do
    Enum.reduce(params, [], fn el, acc ->
      case el do
        {"year_or_location", year_or_location} ->
          if year_or_location =~ ~r/\A\d{4}\Z/ do
            [{:year, validate_and_convert_year(year_or_location)} | acc]
          else
            [{:location, validate_and_convert_location(year_or_location)} | acc]
          end

        {"year", year} ->
          [{:year, validate_and_convert_year(year)} | acc]

        {"location", location_slug} ->
          [{:location, validate_and_convert_location(location_slug)} | acc]

        {_, _} ->
          acc
      end
    end)
    |> Birding.Lifelist.Opts.discombo()
  end

  defp validate_and_convert_location(location_slug) do
    Kjogvi.Geo.location_by_slug!(location_slug)
  end

  defp validate_and_convert_year(year) do
    String.to_integer(year)
  end
end
