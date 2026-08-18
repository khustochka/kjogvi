defmodule Kjogvi.Birding.ChecklistSearch do
  @moduledoc """
  Checklists index search: turns a `ChecklistSearch.Filter` into a paginated page of
  checklists.

  In **checklist mode** (only checklist-level filters, or none) this returns whole checklists
  with their observations preloaded, just like `Kjogvi.Birding.get_checklists/2`.

  In **observation mode** (any observation-level filter active) each returned
  checklist carries *only* the observations that matched the filter, so the index
  can present matching observations grouped under their checklists.
  """

  alias Kjogvi.Birding
  alias Kjogvi.Birding.ChecklistSearch.Filter
  alias Kjogvi.Birding.ChecklistSearch.Query
  alias Kjogvi.Geo
  alias Kjogvi.Repo

  @doc """
  Runs a search for `user` with `filter`, paginated by `%{page:, page_size:}`.

  `filter` may be a `%Filter{}` or a keyword/map of options (validated via
  `Filter.discombo!/1`). Returns `{checklists, %Flop.Meta{}}`.
  """
  def search(user, filter, pagination)

  def search(user, %Filter{} = filter, pagination) do
    Query.matching_checklists(user, filter)
    |> Repo.paginate(pagination)
    |> put_location_levels()
    |> attach_observations(filter)
  end

  def search(user, filter, pagination) do
    search(user, Filter.discombo!(filter), pagination)
  end

  # Batches the level FK associations onto every checklist's location in one query
  # (see `Geo.Location.Query.put_location_levels/1`).
  defp put_location_levels({checklists, meta}) do
    {Geo.Location.Query.put_location_levels(checklists), meta}
  end

  # Only observation mode attaches observations to the checklists; in checklist mode the
  # checklists are returned with observations left unloaded, so the index renders
  # them as plain panels (no per-checklist observation list).
  defp attach_observations({_checklists, _meta} = page, %Filter{} = filter) do
    if Filter.observation_mode?(filter) do
      attach_matching_observations(page, filter)
    else
      page
    end
  end

  # Observation mode: attach only the observations that matched the filter,
  # fetched in one query across all checklists on the page.
  defp attach_matching_observations({checklists, meta}, %Filter{} = filter) do
    checklist_ids = Enum.map(checklists, & &1.id)

    by_checklist =
      Query.observation_filter(checklist_ids, filter)
      |> Repo.all()
      |> load_taxa()
      |> Enum.group_by(& &1.checklist_id)

    {Enum.map(checklists, &%{&1 | observations: Map.get(by_checklist, &1.id, [])}), meta}
  end

  defp load_taxa(observations) do
    Birding.preload_taxa_and_species(observations)
  end
end
