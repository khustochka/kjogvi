defmodule Kjogvi.Birding.Observation.Query do
  @moduledoc """
  Queries for Observation.
  """

  import Ecto.Query

  def exclude_heard_only(query) do
    if has_named_binding?(query, :observation) do
      query
      |> where([observation: o], o.voice == false)
    else
      query
      |> where([..., o], o.voice == false)
    end
  end
end
