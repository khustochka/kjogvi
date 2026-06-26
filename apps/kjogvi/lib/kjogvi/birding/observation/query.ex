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

  def by_card(query, %{id: card_id}) do
    where(query, [o], o.card_id == ^card_id)
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
end
