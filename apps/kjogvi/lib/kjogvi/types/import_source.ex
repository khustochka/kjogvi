defmodule Kjogvi.Types.ImportSource do
  @moduledoc false

  def values, do: [:ebird, :legacy]

  def label(:ebird), do: "eBird"
  def label(:legacy), do: "Legacy"
end
