defmodule Ornitho.Ops do
  def transaction(fun_or_multi, opts \\ []) do
    Ornithologue.repo().transaction(fun_or_multi, opts)
  end
end
