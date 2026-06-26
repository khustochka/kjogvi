defmodule Kjogvi.Birding do
  @moduledoc """
  Birding related functionality (checklists, observations).
  """

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Geo
  alias Kjogvi.Pages.Species

  alias __MODULE__.Observation
  alias __MODULE__.Checklist
  alias __MODULE__.ChecklistSearch
  alias __MODULE__.ChecklistSearch.Filter

  @doc """
  Searches a user's checklists with a `ChecklistSearch.Filter`, paginated.

  See `Kjogvi.Birding.ChecklistSearch.search/3`.
  """
  defdelegate search_checklists(user, filter, pagination), to: ChecklistSearch, as: :search

  @doc """
  Builds a fully-hydrated `ChecklistSearch.Filter` from URL query params.

  Resolves the `location_id` param into a `Geo.Location` and the `taxon_key`
  into a display label, returning `{filter, taxon_label}`. The label lets the
  caller restore the taxon autocomplete's text from a shared/bookmarked URL.
  """
  @spec checklist_filter_from_params(map()) :: {Filter.t(), String.t()}
  def checklist_filter_from_params(params) do
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
        |> Geo.Location.Query.put_levels()
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

  def get_checklists(user, %{page: page, page_size: page_size}) do
    pagination =
      Checklist
      |> Checklist.Query.as_checklist()
      |> Checklist.Query.by_user(user)
      |> order_by([{:desc, :observ_date}, {:desc, :id}])
      |> Checklist.Query.load_observation_count()
      |> Repo.paginate(page: page, page_size: page_size)

    %{pagination | entries: Geo.Location.Query.put_location_levels(pagination.entries)}
  end

  def fetch_checklist_with_observations(user, id) do
    Checklist
    |> Checklist.Query.as_checklist()
    |> Checklist.Query.by_user(user)
    |> Repo.get!(id)
    |> Geo.Location.Query.put_location_levels()
    |> Repo.preload(observations: from(obs in Observation, order_by: obs.id))
    |> then(fn checklist ->
      Map.replace(
        checklist,
        :observations,
        checklist.observations |> Kjogvi.Birding.preload_taxa_and_species()
      )
    end)
  end

  def fetch_checklist_for_edit(user, id) do
    Checklist
    |> Checklist.Query.as_checklist()
    |> Checklist.Query.by_user(user)
    |> Repo.get!(id)
    |> Geo.Location.Query.put_location_levels()
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
      Checklist
      |> Checklist.Query.as_checklist()
      |> Checklist.Query.by_user(user)
      |> Checklist.Query.find_new_checklists(Enum.map(checklists, & &1.ebird_id))
      |> Repo.all()

    Enum.filter(checklists, &(&1.ebird_id in new_ebird_ids))
  end

  def create_checklist(user, attrs) do
    attrs = Map.put(attrs, "user_id", user.id)

    %Checklist{}
    |> Checklist.changeset(attrs)
    |> Repo.insert()
    |> tap_promote_observations()
    |> tap_invalidate_logbook_cache(user.id)
  end

  def update_checklist(checklist, attrs) do
    checklist
    |> Checklist.changeset(attrs)
    |> Repo.update()
    |> tap_promote_observations()
    |> tap_invalidate_logbook_cache(checklist.user_id)
  end

  @doc """
  Deletes a checklist, but only when it has no observations.

  Returns `{:ok, checklist}` on success, or `{:error, :has_observations}` when the
  checklist still has observations and therefore must not be deleted.
  """
  def delete_checklist(%Checklist{} = checklist) do
    if checklist_deletable?(checklist) do
      checklist
      |> Repo.delete()
      |> tap_invalidate_logbook_cache(checklist.user_id)
    else
      {:error, :has_observations}
    end
  end

  @doc """
  Returns `true` when a checklist may be deleted, i.e. it has no observations.

  Relies on the checklist's `observation_count` virtual field when loaded (see
  `Checklist.Query.load_observation_count/1`), otherwise falls back to counting
  observations in the database.
  """
  def checklist_deletable?(%Checklist{observation_count: count}) when is_integer(count) do
    count == 0
  end

  def checklist_deletable?(%Checklist{observations: observations}) when is_list(observations) do
    observations == []
  end

  def checklist_deletable?(%Checklist{id: id}) do
    not Repo.exists?(from(obs in Observation, where: obs.checklist_id == ^id))
  end

  # Create species pages for any of the checklist's observed taxa that lack one,
  # otherwise the species never appears in the lifelist (see Pages.Promotion).
  defp tap_promote_observations({:ok, checklist} = result) do
    Observation.Query.by_checklist(Observation, checklist)
    |> Kjogvi.Pages.Promotion.promote_observations_by_query()

    result
  end

  defp tap_promote_observations(other), do: other

  defp tap_invalidate_logbook_cache({:ok, _} = result, user_id) do
    Kjogvi.Birding.Logbook.Cache.invalidate(user_id)
    result
  end

  defp tap_invalidate_logbook_cache(other, _user_id), do: other

  def new_checklist(user) do
    %Checklist{
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
  Returns a suggested date for a new checklist: the day after the user's latest
  checklist, capped at today. Returns today when the user has no checklists.
  """
  def next_empty_date(user) do
    case last_checklist_date(user) do
      nil ->
        Date.utc_today()

      date ->
        today = Date.utc_today()
        candidate = Date.add(date, 1)
        if Date.compare(candidate, today) == :gt, do: today, else: candidate
    end
  end

  @doc """
  Returns the observation date of the user's most recent checklist, or `nil` when
  the user has no checklists.
  """
  def last_checklist_date(user) do
    Checklist
    |> Checklist.Query.as_checklist()
    |> Checklist.Query.by_user(user)
    |> select([checklist: c], max(c.observ_date))
    |> Repo.one()
  end

  def new_observation() do
    %Observation{
      voice: false,
      hidden: false,
      unreported: false
    }
  end

  def change_checklist(checklist, attrs \\ %{}) do
    Checklist.changeset(checklist, attrs)
  end
end
