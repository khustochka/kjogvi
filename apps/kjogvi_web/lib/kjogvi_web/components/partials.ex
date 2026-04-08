defmodule KjogviWeb.Partials do
  @moduledoc """
  Top level partials.
  """

  use KjogviWeb, :html

  import KjogviWeb.AdminMenuComponents

  require Kjogvi.Config

  embed_templates "partials/*"

  attr :list, :list, doc: "List of observations", required: true
  attr :total, :integer, doc: "Total number of species", required: true
  attr :class, :string, doc: "Class of the top-level section", default: ""
  attr :href, :string, doc: "Link to the full list", default: nil
  slot :header, required: true
  def top_n_list(assigns)

  attr :diary_entries, :list, doc: "List of diary entries", required: true
  def diary(assigns)

  # Private helpers. Move to a separate module if they grow.
  defp diary_area_label(%{area: nil, type: :total}), do: "New lifer:"
  defp diary_area_label(%{area: nil, type: :year, year: year}), do: "New for #{year}:"

  defp diary_area_label(%{area: area, type: :total}),
    do: "New for #{area.name_en}:"

  defp diary_area_label(%{area: area, type: :year, year: year}),
    do: "New for #{area.name_en} #{year}:"
end
