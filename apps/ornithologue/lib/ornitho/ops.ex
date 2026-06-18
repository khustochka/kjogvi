defmodule Ornitho.Ops do
  @moduledoc """
  Ornitho repo operations.
  """

  def transact(fun_or_multi, opts \\ []) do
    Ornithologue.repo().transact(fun_or_multi, opts)
  end

  def insert_all(schema_or_source, entries_or_query, opts \\ []) do
    Ornithologue.repo().insert_all(schema_or_source, entries_or_query, opts)
  end
end
