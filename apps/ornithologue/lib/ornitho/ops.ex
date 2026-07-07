defmodule Ornitho.Ops do
  @moduledoc """
  Ornitho repo operations.
  """

  def transact(fun_or_multi, opts \\ []) do
    Ornitho.Repo.transact(fun_or_multi, opts)
  end

  def insert_all(schema_or_source, entries_or_query, opts \\ []) do
    Ornitho.Repo.insert_all(schema_or_source, entries_or_query, opts)
  end
end
