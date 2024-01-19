defmodule Ornitho.Ops do
  def transaction(fun_or_multi) do
    Ornithologue.repo.transaction(fun_or_multi)
  end
end
