defmodule Kjogvi.Birding.ChecklistSearch.Query do
  @moduledoc """
  Queries backing the checklists index search.

  Two concerns are kept separate:

    * `matching_checklists/2` builds the (named-binding `:checklist`) query of checklists that
      match the filter. Checklist-level filters apply directly; observation-level
      filters constrain it to checklists that have at least one matching observation.
    * `observation_filter/2` builds an `Ecto.Query` over `Observation` that,
      given a list of checklist ids, returns just the observations matching the
      observation-level filters — used to populate each checklist in observation
      mode.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Checklist
  alias Kjogvi.Birding.ChecklistSearch.Filter
  alias Kjogvi.Birding.Observation

  @doc """
  Checklists matching `filter` for `user`, newest first, with per-checklist counts loaded.
  """
  def matching_checklists(user, %Filter{} = filter) do
    Checklist
    |> Checklist.Query.as_checklist()
    |> Checklist.Query.by_user(user)
    |> apply_checklist_filters(filter)
    |> maybe_restrict_to_matching_observations(filter)
    |> order_by([checklist: c], desc: c.observ_date, desc: c.id)
    |> Checklist.Query.load_observation_count()
  end

  # Checklist-level filters: date, location (+ optional subregions), unresolved.
  defp apply_checklist_filters(query, %Filter{} = filter) do
    query
    |> filter_by_date(filter.date)
    |> filter_by_location(filter.location, filter.include_subregions)
    |> filter_by_unresolved(filter.unresolved)
  end

  defp filter_by_date(query, nil), do: query

  defp filter_by_date(query, %Date{} = date) do
    where(query, [checklist: c], c.observ_date == ^date)
  end

  defp filter_by_location(query, nil, _include_subregions), do: query

  defp filter_by_location(query, location, true) do
    Checklist.Query.by_location_with_descendants(query, location)
  end

  defp filter_by_location(query, location, false) do
    where(query, [checklist: c], c.location_id == ^location.id)
  end

  defp filter_by_unresolved(query, false), do: query

  defp filter_by_unresolved(query, true) do
    where(query, [checklist: c], c.resolved == false)
  end

  # When observation-level filters are active, keep only checklists that have at
  # least one observation passing them.
  defp maybe_restrict_to_matching_observations(query, %Filter{} = filter) do
    if Filter.observation_mode?(filter) do
      matching =
        from(o in Observation,
          where: o.checklist_id == parent_as(:checklist).id,
          select: 1
        )
        |> apply_observation_filters(filter)

      where(query, [checklist: c], exists(matching))
    else
      query
    end
  end

  @doc """
  Query over observations belonging to `checklist_ids` that match the
  observation-level filters, ordered for stable display.
  """
  def observation_filter(checklist_ids, %Filter{} = filter) do
    from(o in Observation,
      where: o.checklist_id in ^checklist_ids,
      order_by: [asc: o.checklist_id, asc: o.id]
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
  # as the checklists index is an owner-only view).
  defp filter_by_hidden(query, false), do: query
  defp filter_by_hidden(query, true), do: where(query, [o], o.hidden == true)
end
