defmodule Kjogvi.Birding do
  @moduledoc """
  Birding related functionality (cards, observations).
  """

  import Ecto.Query

  alias Kjogvi.Repo

  alias __MODULE__.Observation
  alias __MODULE__.Card

  def get_cards(%{page: page, page_size: page_size}) do
    Card
    |> order_by([{:desc, :observ_date}, {:desc, :id}])
    |> preload(location: :country)
    |> load_observation_count()
    |> Repo.paginate(page: page, page_size: page_size)
  end

  def fetch_card(id) do
    card =
      Card
      |> Repo.get!(id)
      |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))

    %{card | observations: card.observations}
  end

  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      group_by: c.id,
      select_merge: %{observation_count: count(obs.id)}
    )
  end

  def preload_taxa_and_species(observations) do
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
