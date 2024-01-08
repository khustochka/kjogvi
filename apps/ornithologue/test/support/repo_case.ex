defmodule Ornitho.RepoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ornitho.TestRepo

      import Ecto
      import Ecto.Query
      import Ornitho.RepoCase
      import Ornitho.Factory
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ornitho.TestRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Ornitho.TestRepo, {:shared, self()})
    end

    :ok
  end
end
