defmodule KjogviWeb.Live.Lifelist.Params do
  @moduledoc """
  Normalizing parameters for Lifelist controller.
  """

  alias Kjogvi.Birding

  @valid_year_regex ~r/\A\d{4}\Z/
  @months Enum.map(1..12, &Integer.to_string/1)

  def to_filter(user, params) do
    Enum.reduce(params, {:ok, []}, fn el, acc ->
      add_param(acc, el, user: user, params: params)
    end)
    |> case do
      {:ok, result} ->
        Birding.Lifelist.Filter.discombo(result)

      err ->
        err
    end
  end

  defp add_param(acc, {"year_or_location", year_or_location}, opts) do
    if year_or_location =~ ~r/\A\d+\Z/ do
      add_param(acc, {"year", year_or_location}, opts)
    else
      add_param(acc, {"location", year_or_location}, opts)
    end
  end

  defp add_param(acc, {"location", location_slug}, opts) do
    case Kjogvi.Geo.location_by_slug(opts[:user], location_slug) do
      nil ->
        add_error(acc, "Invalid location.")

      location ->
        add_success(acc, {:location, location})
    end
  end

  defp add_param(acc, {"year", year}, _opts) do
    if year =~ @valid_year_regex do
      add_success(acc, {:year, String.to_integer(year)})
    else
      add_error(acc, "Invalid year value.")
    end
  end

  defp add_param(acc, {"month", month}, _opts) do
    if month in @months do
      add_success(acc, {:month, String.to_integer(month)})
    else
      add_error(acc, "Invalid month value.")
    end
  end

  defp add_param(acc, {"motorless", motorless}, _opts) do
    if motorless == "true" do
      add_success(acc, {:motorless, true})
    else
      acc
    end
  end

  defp add_param(acc, {"exclude_heard_only", exclude_heard_only}, _opts) do
    if exclude_heard_only == "true" do
      add_success(acc, {:exclude_heard_only, true})
    else
      acc
    end
  end

  defp add_param(acc, {_, _}, _opts) do
    acc
  end

  def add_success({:ok, acc}, new_element) do
    {:ok, [new_element | acc]}
  end

  def add_success({:error, _} = error, _new) do
    error
  end

  def add_error({:ok, _}, text) do
    {:error, [text]}
  end

  def add_error({:error, errors}, text) do
    {:error, [text | errors]}
  end
end
