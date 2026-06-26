defmodule Kjogvi.Birding.Checklist.Query do
  @moduledoc """
  Queries for Checklists.
  """

  import Ecto.Query

  alias Kjogvi.Geo

  def as_card(query) do
    from c in query, as: :checklist
  end

  @doc """
  Maps the given checklist ids to their `{inserted_at, updated_at}` timestamps.
  """
  def timestamps_by_id(card_ids) do
    from c in Kjogvi.Birding.Checklist,
      where: c.id in ^card_ids,
      select: {c.id, {c.inserted_at, c.updated_at}}
  end

  def by_year(query, year) when is_integer(year) do
    query
    |> where([..., checklist: c], c.cached_year == ^year)
  end

  def by_month(query, month) when is_integer(month) do
    query
    |> where([..., checklist: c], c.cached_month == ^month)
  end

  def by_user(query, user) do
    query
    |> where([..., checklist: c], c.user_id == ^user.id)
  end

  def motorless(query) do
    query
    |> where([..., checklist: c], c.motorless == true)
  end

  def by_location_with_descendants(query, %{location_type: :special} = special) do
    child_ids = Geo.Location.Query.special_descendant_ids(special)

    from [..., checklist: c] in query,
      where: c.location_id in subquery(child_ids)
  end

  # Performance is roughly the same but we avoid joining with locations
  def by_location_with_descendants(query, location) do
    child_ids =
      from(Geo.Location.Query.child_locations(location))
      |> select([l], l.id)

    from [..., checklist: c] in query,
      where: c.location_id in subquery(child_ids)
  end

  @doc """
  Loads per-checklist aggregates: total number of observations, number of distinct
  taxa, and number of distinct countable species.

  Countable species are derived from the species/taxa mapping and exclude
  observations marked as `unreported`.
  """
  def load_observation_count(query) do
    from(c in query,
      left_join: obs in assoc(c, :observations),
      left_join: stm in assoc(obs, :species_taxa_mapping),
      group_by: c.id,
      select_merge: %{
        observation_count: count(obs.id),
        taxa_count: count(fragment("DISTINCT ?", obs.taxon_key)),
        species_count:
          count(
            fragment(
              "DISTINCT CASE WHEN ? = false THEN ? END",
              obs.unreported,
              stm.species_page_id
            )
          )
      }
    )
  end

  def all_ebird_ids(query) do
    from(c in query,
      where: not is_nil(c.ebird_id),
      select: c.ebird_id
    )
  end

  def find_new_checklists(query, new_ebird_ids) do
    from(
      l in fragment("SELECT checklist_id FROM UNNEST(?::text[]) AS checklist_id", ^new_ebird_ids),
      where: l.checklist_id not in subquery(all_ebird_ids(query)),
      select: l.checklist_id
    )
  end
end
