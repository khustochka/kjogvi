defmodule KjogviWeb.HomeHTML do
  @moduledoc """
  This module contains pages rendered by HomeController.

  See the `home_html` directory for all templates available.
  """
  use KjogviWeb, :html

  import KjogviWeb.Partials

  @doc """
  Returns a human-readable label for the area of a diary event.
  nil area = World; otherwise use location name.
  """
  def diary_area_label(%{area: nil, type: :total}), do: "New lifer:"
  def diary_area_label(%{area: nil, type: :year, year: year}), do: "New for #{year}:"

  def diary_area_label(%{area: area, type: :total}),
    do: "New for #{area.name_en}:"

  def diary_area_label(%{area: area, type: :year, year: year}),
    do: "New for #{area.name_en} #{year}:"

  embed_templates "home_html/*"
end
