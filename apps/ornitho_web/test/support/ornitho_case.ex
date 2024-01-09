defmodule OrnithoWeb.OrnithoCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Kjogvi.OrnithoRepo

      import Ecto
      import Ecto.Query
      import OrnithoWeb.OrnithoCase
      import Ornitho.Factory
    end
  end

  setup tags do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Kjogvi.OrnithoRepo)

    unless tags[:async] do
      Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, {:shared, self()})
    end

    :ok
  end
end
