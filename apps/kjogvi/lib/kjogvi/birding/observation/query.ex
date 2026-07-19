defmodule Kjogvi.Birding.Observation.Query do
  @moduledoc """
  Queries for Observation.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Observation

  @doc """
  Base query of a scope's reportable observations, joined to their checklist and
  species/taxa mapping.

  Named bindings `:observation`, `:checklist`, and `:stm` are set so callers can
  extend the query without relying on positional order. Always excludes
  unreported observations and restricts to the scope's subject user (unless the
  scope has no subject user, in which case observations are aggregated across
  all users — the community lifelist). Hidden observations are excluded unless
  the scope's visibility is `:private` — this is the single place that privacy
  rule is applied for observation feeds, so lifelist and logbook stay consistent.
  """
  @spec base_for_scope(Kjogvi.Scope.t()) :: Ecto.Query.t()
  def base_for_scope(%Kjogvi.Scope{} = scope) do
    base_query()
    |> maybe_for_user(Kjogvi.Scope.subject_user(scope))
    |> maybe_exclude_hidden(Kjogvi.Scope.visibility(scope))
  end

  defp maybe_for_user(query, nil), do: query

  defp maybe_for_user(query, %{id: user_id}),
    do: where(query, [checklist: c], c.user_id == ^user_id)

  defp base_query do
    from o in Observation,
      as: :observation,
      join: c in assoc(o, :checklist),
      as: :checklist,
      join: stm in assoc(o, :species_taxa_mapping),
      as: :stm,
      where: o.unreported == false
  end

  defp maybe_exclude_hidden(query, :private), do: query
  defp maybe_exclude_hidden(query, :public), do: exclude_hidden(query)

  def by_checklist(query, %{id: checklist_id}) do
    where(query, [o], o.checklist_id == ^checklist_id)
  end

  def exclude_heard_only(query) do
    if has_named_binding?(query, :observation) do
      query
      |> where([observation: o], o.voice == false)
    else
      query
      |> where([..., o], o.voice == false)
    end
  end

  def only_heard_only(query) do
    if has_named_binding?(query, :observation) do
      query
      |> where([observation: o], o.voice == true)
    else
      query
      |> where([..., o], o.voice == true)
    end
  end

  def exclude_hidden(query) do
    if has_named_binding?(query, :observation) do
      query
      |> where([observation: o], o.hidden == false)
    else
      query
      |> where([..., o], o.hidden == false)
    end
  end

  @doc """
  Base query of observations joined to their checklist, without the reportability
  and privacy filters of `base_for_scope/1`.

  Used by the image observation picker, which searches a user's own observations
  and so applies its own ownership scoping via `owned_by/2`.
  """
  def with_checklist do
    from o in Observation,
      as: :observation,
      join: c in assoc(o, :checklist),
      as: :checklist
  end

  @doc """
  Restricts to observations on the checklists of `user` (a struct or a user id).
  """
  def owned_by(query, %{id: user_id}), do: owned_by(query, user_id)

  def owned_by(query, user_id) when is_integer(user_id) do
    where(query, [checklist: c], c.user_id == ^user_id)
  end

  @doc """
  Restricts to the given observation ids.
  """
  def with_ids(query, observation_ids) when is_list(observation_ids) do
    where(query, [observation: o], o.id in ^observation_ids)
  end

  @doc """
  Restricts to observations of the given taxon keys.
  """
  def with_taxon_keys(query, taxon_keys) when is_list(taxon_keys) do
    where(query, [observation: o], o.taxon_key in ^taxon_keys)
  end

  @doc """
  Restricts to observations on the given checklist.
  """
  def on_checklist(query, checklist_id) do
    where(query, [observation: o], o.checklist_id == ^checklist_id)
  end

  @doc """
  Restricts to observations on checklists of the given date.
  """
  def on_date(query, %Date{} = date) do
    where(query, [checklist: c], c.observ_date == ^date)
  end

  @doc """
  Orders by newest checklist first.
  """
  def newest_checklist_first(query) do
    order_by(query, [checklist: c], desc: c.observ_date, desc: c.id)
  end

  @doc """
  Caps the number of returned observations.
  """
  def limit_to(query, count) when is_integer(count) do
    limit(query, ^count)
  end

  @doc """
  Preloads each observation's checklist with its location.
  """
  def preload_checklist_location(query) do
    preload(query, [checklist: c], checklist: {c, :location})
  end
end
