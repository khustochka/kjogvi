defmodule KjogviWeb.OrnithoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Ornitho.Repo

      import Ecto
      import Ecto.Query
      import KjogviWeb.OrnithoCase
      import Ornitho.Factory
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Ornitho.Repo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Ornitho.Repo, {:shared, self()})
    end

    :ok
  end
end
