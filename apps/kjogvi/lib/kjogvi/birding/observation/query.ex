defmodule Kjogvi.Birding.Observation.Query do
  @moduledoc """
  Queries for Observation.
  """

  import Ecto.Query

  alias Kjogvi.Birding.Observation

  @doc """
  Base query of a scope's reportable observations, joined to their card and
  species/taxa mapping.

  Named bindings `:observation`, `:card`, and `:stm` are set so callers can
  extend the query without relying on positional order. Always excludes
  unreported observations and restricts to the scope's user (unless the scope
  has no `user`, in which case observations are aggregated across all users —
  the community lifelist). Hidden observations are excluded unless
  `scope.include_private` is true — this is the single place that privacy rule
  is applied for observation feeds, so lifelist and logbook stay consistent.
  """
  def base_for_scope(%{user: %{id: user_id}, include_private: include_private}) do
    base_query()
    |> where([card: c], c.user_id == ^user_id)
    |> maybe_exclude_hidden(include_private)
  end

  def base_for_scope(%{user: nil, include_private: include_private}) do
    base_query()
    |> maybe_exclude_hidden(include_private)
  end

  defp base_query do
    from o in Observation,
      as: :observation,
      join: c in assoc(o, :card),
      as: :card,
      join: stm in assoc(o, :species_taxa_mapping),
      as: :stm,
      where: o.unreported == false
  end

  defp maybe_exclude_hidden(query, true = _include_private), do: query
  defp maybe_exclude_hidden(query, false = _include_private), do: exclude_hidden(query)

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
