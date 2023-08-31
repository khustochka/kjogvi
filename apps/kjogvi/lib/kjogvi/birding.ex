defmodule Kjogvi.Birding do
  @moduledoc """
  Birding related functionality (locations, cards, observations).
  """

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
    card =
      Card
      |> Repo.get!(id)
      |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))

    %{card | observations: preload_taxa_and_species(card.observations)}
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
    |> Repo.all()
    |> Enum.map(&Repo.load(LifeObservation, &1))
    |> Repo.preload(:location)
    |> preload_taxa_and_species
    |> Enum.filter(fn rec -> rec.species end)
    |> Enum.uniq_by(fn rec -> rec.species.code end)
  end

  defp lifelist_query do
    from l in subquery(lifers_query()),
      order_by: [desc: l.observ_date, desc_nulls_first: l.start_time, desc: l.id]
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

  defp preload_taxa_and_species(observations) do
    taxa =
      for obs <- observations, uniq: true do
        obs.taxon_key
      end
      |> Ornithologue.get_taxa_and_species()

    for obs <- observations do
      taxon = taxa[obs.taxon_key]
      %{obs | taxon: taxon, species: Ornitho.Schema.Taxon.species(taxon)}
    end
  end
end
