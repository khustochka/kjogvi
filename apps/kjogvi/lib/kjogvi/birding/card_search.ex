defmodule Kjogvi.Birding.CardSearch do
  @moduledoc """
  Cards index search: turns a `CardSearch.Filter` into a paginated page of
  cards.

  In **card mode** (only card-level filters, or none) this returns whole cards
  with their observations preloaded, just like `Kjogvi.Birding.get_cards/2`.

  In **observation mode** (any observation-level filter active) each returned
  card carries *only* the observations that matched the filter, so the index
  can present matching observations grouped under their cards.
  """

  alias Kjogvi.Birding
  alias Kjogvi.Birding.CardSearch.Filter
  alias Kjogvi.Birding.CardSearch.Query
  alias Kjogvi.Repo

  @doc """
  Runs a search for `user` with `filter`, paginated by `%{page:, page_size:}`.

  `filter` may be a `%Filter{}` or a keyword/map of options (validated via
  `Filter.discombo!/1`). Returns a `Scrivener.Page` of cards.
  """
  def search(user, filter, pagination)

  def search(user, %Filter{} = filter, %{page: page, page_size: page_size}) do
    Query.matching_cards(user, filter)
    |> Repo.paginate(page: page, page_size: page_size)
    |> attach_observations(filter)
  end

  def search(user, filter, pagination) do
    search(user, Filter.discombo!(filter), pagination)
  end

  # Only observation mode attaches observations to the cards; in card mode the
  # cards are returned with observations left unloaded, so the index renders
  # them as plain panels (no per-card observation list).
  defp attach_observations(%Scrivener.Page{} = page, %Filter{} = filter) do
    if Filter.observation_mode?(filter) do
      attach_matching_observations(page, filter)
    else
      page
    end
  end

  # Observation mode: attach only the observations that matched the filter,
  # fetched in one query across all cards on the page.
  defp attach_matching_observations(%Scrivener.Page{entries: cards} = page, %Filter{} = filter) do
    card_ids = Enum.map(cards, & &1.id)

    by_card =
      Query.observation_filter(card_ids, filter)
      |> Repo.all()
      |> load_taxa()
      |> Enum.group_by(& &1.card_id)

    cards = Enum.map(cards, &%{&1 | observations: Map.get(by_card, &1.id, [])})

    %{page | entries: cards}
  end

  defp load_taxa(observations) do
    Birding.preload_taxa_and_species(observations)
  end
end
