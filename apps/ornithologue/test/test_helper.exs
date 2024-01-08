Application.put_env(:ornithologue, :repo, Ornitho.TestRepo)

Application.put_env(:ornithologue, Ornitho.TestRepo,
  hostname: System.get_env("ORNITHO_DATABASE_HOST", "localhost"),
  port: System.get_env("ORNITHO_DATABASE_PORT"),
  password: System.get_env("ORNITHO_DATABASE_PASSWORD"),
  database:
    System.get_env(
      "ORNITHO_DATABASE_NAME",
      "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
)

defmodule Ornitho.TestRepo do
  use Ecto.Repo, otp_app: :ornithologue, adapter: Ecto.Adapters.Postgres
end

_ = Ecto.Adapters.Postgres.storage_up(Ornitho.TestRepo.config())

opts = [strategy: :one_for_one, name: OrnithologueTest.Supervisor]
Supervisor.start_link([Ornitho.TestRepo], opts)

ExUnit.start()

Ecto.Adapters.SQL.Sandbox.mode(Ornitho.TestRepo, :manual)
