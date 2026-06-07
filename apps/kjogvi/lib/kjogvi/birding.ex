defmodule Kjogvi.Birding do
  @moduledoc """
  Birding related functionality (cards, observations).
  """

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Geo
  alias Kjogvi.Pages.Species

  alias __MODULE__.Observation
  alias __MODULE__.Card
  alias __MODULE__.CardSearch
  alias __MODULE__.CardSearch.Filter

  @doc """
  Searches a user's cards with a `CardSearch.Filter`, paginated.

  See `Kjogvi.Birding.CardSearch.search/3`.
  """
  defdelegate search_cards(user, filter, pagination), to: CardSearch, as: :search

  @doc """
  Builds a fully-hydrated `CardSearch.Filter` from URL query params.

  Resolves the `location_id` param into a `Geo.Location` and the `taxon_key`
  into a display label, returning `{filter, taxon_label}`. The label lets the
  caller restore the taxon autocomplete's text from a shared/bookmarked URL.
  """
  @spec card_filter_from_params(map()) :: {Filter.t(), String.t()}
  def card_filter_from_params(params) do
    {filter, location_id} = Filter.from_params(params)

    filter = %{filter | location: resolve_location(location_id)}
    {filter, taxon_label(filter.taxon_key)}
  end

  defp resolve_location(nil), do: nil

  defp resolve_location(id) do
    case Integer.parse(id) do
      {int_id, ""} ->
        Geo.get_locations_by_ids([int_id])
        # Match the preloads the location autocomplete attaches, so the filter
        # panel can render the location's long name from a shared/bookmarked URL.
        |> Repo.preload(Geo.Location.Query.display_assocs())
        |> List.first()

      _ ->
        nil
    end
  end

  defp taxon_label(nil), do: ""

  defp taxon_label(taxon_key) do
    case Ornithologue.get_taxa_and_species([taxon_key]) do
      %{^taxon_key => %{name_en: name_en}} when is_binary(name_en) -> name_en
      _ -> ""
    end
  end

  def get_cards(user, %{page: page, page_size: page_size}) do
    Card
    |> Card.Query.as_card()
    |> Card.Query.by_user(user)
    |> order_by([{:desc, :observ_date}, {:desc, :id}])
    |> Geo.Location.Query.preload_display()
    |> Card.Query.load_observation_count()
    |> Repo.paginate(page: page, page_size: page_size)
  end

  def fetch_card_with_observations(user, id) do
    Card
    |> Card.Query.as_card()
    |> Card.Query.by_user(user)
    |> Geo.Location.Query.preload_display()
    |> Repo.get!(id)
    |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))
    |> then(fn card ->
      Map.replace(
        card,
        :observations,
        card.observations |> Kjogvi.Birding.preload_taxa_and_species()
      )
    end)
  end

  def fetch_card_for_edit(user, id) do
    Card
    |> Card.Query.as_card()
    |> Card.Query.by_user(user)
    |> Geo.Location.Query.preload_display()
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
      %{obs | taxon: taxon, species: Ornitho.Schema.Taxon.species(taxon) |> Species.from_taxon()}
    end
  end

  def find_new_checklists(user, checklists) do
    new_ebird_ids =
      Card
      |> Card.Query.as_card()
      |> Card.Query.by_user(user)
      |> Card.Query.find_new_checklists(Enum.map(checklists, & &1.ebird_id))
      |> Repo.all()

    Enum.filter(checklists, &(&1.ebird_id in new_ebird_ids))
  end

  def create_card(user, attrs) do
    attrs = Map.put(attrs, "user_id", user.id)

    %Card{}
    |> Card.changeset(attrs)
    |> Repo.insert()
    |> tap_invalidate_logbook_cache(user.id)
  end

  def update_card(card, attrs) do
    card
    |> Card.changeset(attrs)
    |> Repo.update()
    |> tap_invalidate_logbook_cache(card.user_id)
  end

  @doc """
  Deletes a card, but only when it has no observations.

  Returns `{:ok, card}` on success, or `{:error, :has_observations}` when the
  card still has observations and therefore must not be deleted.
  """
  def delete_card(%Card{} = card) do
    if card_deletable?(card) do
      card
      |> Repo.delete()
      |> tap_invalidate_logbook_cache(card.user_id)
    else
      {:error, :has_observations}
    end
  end

  @doc """
  Returns `true` when a card may be deleted, i.e. it has no observations.

  Relies on the card's `observation_count` virtual field when loaded (see
  `Card.Query.load_observation_count/1`), otherwise falls back to counting
  observations in the database.
  """
  def card_deletable?(%Card{observation_count: count}) when is_integer(count) do
    count == 0
  end

  def card_deletable?(%Card{observations: observations}) when is_list(observations) do
    observations == []
  end

  def card_deletable?(%Card{id: id}) do
    not Repo.exists?(from(obs in Observation, where: obs.card_id == ^id))
  end

  defp tap_invalidate_logbook_cache({:ok, _} = result, user_id) do
    Kjogvi.Birding.Logbook.Cache.invalidate(user_id)
    result
  end

  defp tap_invalidate_logbook_cache(other, _user_id), do: other

  def new_card(user) do
    %Card{
      user_id: user.id,
      observ_date: next_empty_date(user),
      effort_type: "INCIDENTAL",
      motorless: false,
      legacy_autogenerated: false,
      resolved: true,
      observations: []
    }
  end

  @doc """
  Returns a suggested date for a new card: the day after the user's latest
  card, capped at today. Returns today when the user has no cards.
  """
  def next_empty_date(user) do
    case last_card_date(user) do
      nil ->
        Date.utc_today()

      date ->
        today = Date.utc_today()
        candidate = Date.add(date, 1)
        if Date.compare(candidate, today) == :gt, do: today, else: candidate
    end
  end

  @doc """
  Returns the observation date of the user's most recent card, or `nil` when
  the user has no cards.
  """
  def last_card_date(user) do
    Card
    |> Card.Query.as_card()
    |> Card.Query.by_user(user)
    |> select([card: c], max(c.observ_date))
    |> Repo.one()
  end

  def new_observation() do
    %Observation{
      voice: false,
      hidden: false,
      unreported: false
    }
  end

  def change_card(card, attrs \\ %{}) do
    Card.changeset(card, attrs)
  end
end
