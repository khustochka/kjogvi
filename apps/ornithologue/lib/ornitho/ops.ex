defmodule Ornitho.Ops do
  @moduledoc """
  Ornitho repo operations.
  """

  def transact(fun_or_multi, opts \\ []) do
    Ornithologue.repo().transact(fun_or_multi, opts)
  end
end
