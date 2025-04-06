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

  @doc """
  Values for the robots meta tag.
  """

  # Full motorless checklist - indexed
  def robots(%{year: nil, location: nil, month: nil, motorless: true, exclude_heard_only: nil}) do
    nil
  end

  # Any other motorless - not indexed
  def robots(%{motorless: true}) do
    [:noindex]
  end

  # Exclude heard only - not indexed
  def robots(%{exclude_heard_only: true}) do
    [:noindex]
  end

  # Month lists - not indexed
  def robots(%{month: month}) when not is_nil(month) do
    [:noindex]
  end

  # Year lists - not indexed
  def robots(%{year: year}) when not is_nil(year) do
    nil
  end

  # Lifelist for diff locations and world are indexed (# TODO: only countries)
  def robots(%{year: nil}) do
    nil
  end

  def robots(_) do
    nil
  end
end
