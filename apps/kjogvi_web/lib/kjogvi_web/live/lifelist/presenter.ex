defmodule KjogviWeb.Live.Lifelist.Presenter do
  @moduledoc """
  Presentational stuff for Lifelist.
  """

  alias Kjogvi.Birding.Lifelist

  @doc """
  Generates Lifelist title based on filter
  """
  def title(keyword) when is_list(keyword) do
    keyword
    |> Lifelist.Filter.discombo!()
    |> title
  end

  def title(%{year: nil, location: nil, month: nil}) do
    "Lifelist"
  end

  def title(%{year: nil, location: nil, month: month}) do
    "#{Timex.month_name(month)} Lifelist"
  end

  def title(%{year: year, location: nil, month: nil}) do
    "#{year} Year List"
  end

  def title(%{year: year, location: nil, month: month}) do
    "#{Timex.month_name(month)} #{year} List"
  end

  def title(%{year: nil, location: location, month: nil}) do
    "#{location.name_en} Life List"
  end

  def title(%{year: nil, location: location, month: month}) do
    "#{location.name_en} #{Timex.month_name(month)} List"
  end

  def title(%{year: year, location: location, month: nil}) do
    "#{year} #{location.name_en} List"
  end

  def title(%{year: year, location: location, month: month}) do
    "#{Timex.month_name(month)} #{year} #{location.name_en} List"
  end
end
