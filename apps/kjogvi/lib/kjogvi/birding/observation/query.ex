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
  unreported observations and restricts to the scope's user. Hidden
  observations are excluded unless `scope.include_private` is true — this is
  the single place that privacy rule is applied for observation feeds, so
  lifelist and logbook stay consistent.
  """
  def base_for_scope(%{user: %{id: user_id}, include_private: include_private}) do
    query =
      from o in Observation,
        as: :observation,
        join: c in assoc(o, :card),
        as: :card,
        join: stm in assoc(o, :species_taxa_mapping),
        as: :stm,
        where: o.unreported == false and c.user_id == ^user_id

    if include_private do
      query
    else
      exclude_hidden(query)
    end
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
