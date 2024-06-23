defmodule KjogviWeb.Live.Lifelist.Params do
  @moduledoc """
  Normalizing parameters for Lifelist controller.
  """

  alias Kjogvi.Birding

  def to_filter(user, params) do
    Enum.reduce(params, [], fn el, acc ->
      add_param(acc, el, user: user, params: params)
    end)
    |> Birding.Lifelist.Opts.discombo()
  end

  defp add_param(acc, {"year_or_location", year_or_location}, opts) do
    if year_or_location =~ ~r/\A\d{4}\Z/ do
      [{:year, validate_and_convert_year(year_or_location)} | acc]
    else
      [{:location, validate_and_convert_location(opts[:user], year_or_location)} | acc]
    end
  end

  defp add_param(acc, {"year", year}, _opts) do
    [{:year, validate_and_convert_year(year)} | acc]
  end

  defp add_param(acc, {"location", location_slug}, opts) do
    [{:location, validate_and_convert_location(opts[:user], location_slug)} | acc]
  end

  defp add_param(acc, {_, _}, _opts) do
    acc
  end

  defp validate_and_convert_location(user, location_slug) do
    Kjogvi.Geo.location_by_slug!(user, location_slug)
  end

  defp validate_and_convert_year(year) do
    String.to_integer(year)
  end
end
