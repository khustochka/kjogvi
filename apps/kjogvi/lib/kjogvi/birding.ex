defmodule Kjogvi.Birding do
  import Ecto.Query

  alias Kjogvi.Repo

  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.Location
  alias Kjogvi.Birding.Observation

  def get_cards(%{page: page, page_size: page_size}) do
    Card
    |> order_by([{:desc, :observ_date}, {:desc, :id}])
    |> preload(:location)
    |> load_observation_count()
    |> Repo.paginate(page: page, page_size: page_size)
  end

  def fetch_card(id) do
    Card
    |> Repo.get!(id)
    |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))
  end

  def get_locations do
    Location |> Repo.all()
  end

  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      group_by: c.id,
      select_merge: %{observation_count: count(obs.id)}
    )
  end
end
