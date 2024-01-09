if !function_exported?(Kjogvi.OrnithoRepo, :__info__, 1) do
  defmodule Kjogvi.OrnithoRepo do
    use Ecto.Repo,
      otp_app: :kjogvi,
      adapter: Ecto.Adapters.Postgres
  end

  _ = Ecto.Adapters.Postgres.storage_up(Kjogvi.OrnithoRepo.config())

  opts = [strategy: :one_for_one, name: OrnithologueTest.Supervisor]
  Supervisor.start_link([Kjogvi.OrnithoRepo], opts)
end

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :manual)
