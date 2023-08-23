defmodule Kjogvi.Birding do
  import Ecto.Query

  alias Kjogvi.Repo

  alias __MODULE__.Observation
  alias __MODULE__.Card
  alias __MODULE__.Location
  alias __MODULE__.LifeObservation

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
    Location
    |> Repo.all()
  end

  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      group_by: c.id,
      select_merge: %{observation_count: count(obs.id)}
    )
  end

  def lifelist do
    lifelist_query()
    |> Repo.all
    |> Enum.map(&(Repo.load(LifeObservation, &1)))
    |> Repo.preload(:location)
  end

  defp lifelist_query do
    from l in subquery(lifers_query()),
      order_by: [asc: l.observ_date, asc_nulls_last: l.start_time, asc: l.id]
  end

  defp lifers_query do
    from o in Observation,
      distinct: o.taxon_key,
      join: c in assoc(o, :card),
      where: o.unreported == false,
      order_by: [asc: o.taxon_key, asc: c.observ_date, asc_nulls_last: c.start_time, asc: o.id],
      select: %{
        id: o.id,
        card_id: c.id,
        taxon_key: o.taxon_key,
        observ_date: c.observ_date,
        start_time: c.start_time,
        location_id: coalesce(o.patch_id, c.location_id)
      }
  end
end
