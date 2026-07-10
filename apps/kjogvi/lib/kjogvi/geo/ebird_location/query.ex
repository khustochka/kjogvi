defmodule Kjogvi.Geo.EbirdLocation.Query do
  @moduledoc """
  Queries for eBird locations.
  """

  import Ecto.Query

  alias Kjogvi.Geo.EbirdLocation

  def order_by_code(query \\ EbirdLocation) do
    from e in query, order_by: e.code
  end

  def for_country(query \\ EbirdLocation, country_code) do
    from e in query, where: e.country_code == ^country_code
  end

  @doc """
  Rows linked to a common location.
  """
  def matched(query \\ EbirdLocation) do
    from e in query, where: not is_nil(e.location_id)
  end

  @doc """
  Per-type totals with the matched (linked) count:
  `{location_type, total, matched}` rows.
  """
  def count_by_type_with_matched(query \\ EbirdLocation) do
    from e in query,
      group_by: e.location_type,
      select: {e.location_type, count(e.id), count(e.location_id)}
  end
end
