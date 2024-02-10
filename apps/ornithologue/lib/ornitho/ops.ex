defmodule Ornitho.Ops do
  @moduledoc """
  Ornitho repo operations.
  """

  def transaction(fun_or_multi, opts \\ []) do
    Ornithologue.repo().transaction(fun_or_multi, opts)
  end
end
