defmodule Kjogvi.Birding do
  @moduledoc """
  Birding related functionality (cards, observations).
  """

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Query

  alias __MODULE__.Observation
  alias __MODULE__.Card

  def get_cards(%{page: page, page_size: page_size}) do
    Card
    |> order_by([{:desc, :observ_date}, {:desc, :id}])
    |> preload(location: :country)
    |> Query.Card.load_observation_count()
    |> Repo.paginate(page: page, page_size: page_size)
  end

  def fetch_card(id) do
    Card
    |> Repo.get!(id)
    |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))
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
