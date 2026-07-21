defmodule Kjogvi.Ebird.UserLocation.Query do
  @moduledoc """
  Queries for `Kjogvi.Ebird.UserLocation`.
  """

  import Ecto.Query

  alias Kjogvi.Ebird.UserLocation

  def by_user(query \\ UserLocation, user) do
    from ul in query, where: ul.user_id == ^user.id
  end

  @doc """
  The user's eBird locations keyed by `ebird_loc_id`.
  """
  def by_ebird_loc_id(query \\ UserLocation, ebird_loc_ids) do
    from ul in query, where: ul.ebird_loc_id in ^ebird_loc_ids
  end
end
