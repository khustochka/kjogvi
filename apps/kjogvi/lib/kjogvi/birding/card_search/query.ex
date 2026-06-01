defmodule Kjogvi.Birding.CardSearch.Query do
  @moduledoc """
  Queries backing the cards index search.

  Two concerns are kept separate:

    * `matching_cards/2` builds the (named-binding `:card`) query of cards that
      match the filter. Card-level filters apply directly; observation-level
      filters constrain it to cards that have at least one matching observation.
    * `observation_filter/2` builds an `Ecto.Query` over `Observation` that,
      given a list of card ids, returns just the observations matching the
      observation-level filters — used to populate each card in observation
      mode.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Card
  alias Kjogvi.Birding.CardSearch.Filter
  alias Kjogvi.Birding.Observation
  alias Kjogvi.Geo

  @doc """
  Cards matching `filter` for `user`, newest first, with per-card counts loaded.
  """
  def matching_cards(user, %Filter{} = filter) do
    Card
    |> Card.Query.as_card()
    |> Card.Query.by_user(user)
    |> apply_card_filters(filter)
    |> maybe_restrict_to_matching_observations(filter)
    |> order_by([card: c], desc: c.observ_date, desc: c.id)
    |> Geo.Location.Query.preload_display()
    |> Card.Query.load_observation_count()
  end

  # Card-level filters: date, location (+ optional subregions).
  defp apply_card_filters(query, %Filter{} = filter) do
    query
    |> filter_by_date(filter.date)
    |> filter_by_location(filter.location, filter.include_subregions)
  end

  defp filter_by_date(query, nil), do: query

  defp filter_by_date(query, %Date{} = date) do
    where(query, [card: c], c.observ_date == ^date)
  end

  defp filter_by_location(query, nil, _include_subregions), do: query

  defp filter_by_location(query, location, true) do
    Card.Query.by_location_with_descendants(query, location)
  end

  defp filter_by_location(query, location, false) do
    where(query, [card: c], c.location_id == ^location.id)
  end

  # When observation-level filters are active, keep only cards that have at
  # least one observation passing them.
  defp maybe_restrict_to_matching_observations(query, %Filter{} = filter) do
    if Filter.observation_mode?(filter) do
      matching =
        from(o in Observation,
          where: o.card_id == parent_as(:card).id,
          select: 1
        )
        |> apply_observation_filters(filter)

      where(query, [card: c], exists(matching))
    else
      query
    end
  end

  @doc """
  Query over observations belonging to `card_ids` that match the
  observation-level filters, ordered for stable display.
  """
  def observation_filter(card_ids, %Filter{} = filter) do
    from(o in Observation,
      where: o.card_id in ^card_ids,
      order_by: [asc: o.card_id, asc: o.id]
    )
    |> apply_observation_filters(filter)
  end

  # Observation-level filters: taxon (+ subspecies rollup), voice, hidden.
  defp apply_observation_filters(query, %Filter{} = filter) do
    query
    |> filter_by_taxon(filter.taxon_key, filter.exclude_subspecies)
    |> filter_by_voice(filter.voice)
    |> filter_by_hidden(filter.hidden)
  end

  defp filter_by_taxon(query, nil, _exclude_subspecies), do: query

  # Exact taxon only.
  defp filter_by_taxon(query, taxon_key, true) do
    where(query, [o], o.taxon_key == ^taxon_key)
  end

  # The selected taxon, plus any taxon that maps to the same species (i.e. its
  # subspecies and sibling forms).
  defp filter_by_taxon(query, taxon_key, false) do
    species_ids =
      from(stm in Kjogvi.Pages.SpeciesTaxaMapping,
        where: stm.taxon_key == ^taxon_key,
        select: stm.species_page_id
      )

    sibling_keys =
      from(stm in Kjogvi.Pages.SpeciesTaxaMapping,
        where: stm.species_page_id in subquery(species_ids),
        select: stm.taxon_key
      )

    where(query, [o], o.taxon_key == ^taxon_key or o.taxon_key in subquery(sibling_keys))
  end

  defp filter_by_voice(query, :all), do: query
  defp filter_by_voice(query, :seen), do: Observation.Query.exclude_heard_only(query)
  defp filter_by_voice(query, :heard_only), do: Observation.Query.only_heard_only(query)

  # `hidden` selects ONLY hidden observations when checked; when unchecked it
  # leaves the default behaviour (hidden ones are included for the owner here,
  # as the cards index is an owner-only view).
  defp filter_by_hidden(query, false), do: query
  defp filter_by_hidden(query, true), do: where(query, [o], o.hidden == true)
end
