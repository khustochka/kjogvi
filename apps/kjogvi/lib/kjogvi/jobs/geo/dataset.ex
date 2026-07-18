defmodule Kjogvi.Jobs.Geo.Dataset do
  @moduledoc """
  Shared `"dataset"` arg handling for the geo dataset jobs
  (`Kjogvi.Jobs.Geo.Restore`, `Kjogvi.Jobs.Geo.Dump`).
  """

  @key_parts %{"common_locations" => :common, "ebird_locations" => :ebird}
  @labels %{"common_locations" => "common locations", "ebird_locations" => "eBird locations"}

  @doc """
  The `Kjogvi.Geo` dataset named by the job arg.
  """
  def parse("common_locations"), do: :common_locations
  def parse("ebird_locations"), do: :ebird_locations

  @doc """
  The dataset's part in the task key, e.g. the `:common` in `{:geo_restore, :common}`.
  """
  def key_part(dataset), do: Map.fetch!(@key_parts, dataset)

  def label(dataset), do: Map.fetch!(@labels, dataset)
end
