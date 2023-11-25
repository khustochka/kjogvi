defmodule Kjogvi.Geo do
  @moduledoc """
  Geography related functionality (countries, regions, locations).
  """

  import Ecto.Query

  alias Kjogvi.Repo

  alias __MODULE__.Location

  def get_locations do
    Location
    |> load_cards_count()
    |> Repo.all()
  end

  defp load_cards_count(query) do
    from(l in query,
      left_join: c in assoc(l, :cards),
      group_by: l.id,
      select_merge: %{cards_count: count(c.id)}
    )
  end
end
