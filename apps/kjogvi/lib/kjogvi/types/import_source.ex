defmodule Kjogvi.Types.ImportSource do
  @moduledoc false

  # `:ebird` is personal data from a user's eBird import; `:iso` and
  # `:ebird_regions` mark common locations seeded from the ISO 3166 and eBird
  # region datasets.
  def values, do: [:ebird, :legacy, :iso, :ebird_regions]

  def label(:ebird), do: "eBird"
  def label(:legacy), do: "Legacy"
  def label(:iso), do: "ISO 3166"
  def label(:ebird_regions), do: "eBird Regions"
end
