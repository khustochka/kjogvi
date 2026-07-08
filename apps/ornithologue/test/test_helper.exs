# The library tests run against their own standalone repo and database,
# independent of any host app configuration. The host config is restored
# after the suite — umbrella-wide test runs share one VM across suites.
previous_repo = Application.get_env(:ornithologue, :repo)
previous_prefix = Application.get_env(:ornithologue, :prefix)

Application.put_env(:ornithologue, Kjogvi.OrnithoRepo,
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: System.get_env("DATABASE_PORT", "5498"),
  username: System.get_env("DATABASE_USER", "kjogvi"),
  password: System.get_env("DATABASE_PASSWORD", "kjogvi"),
  database: "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
)

Application.put_env(:ornithologue, :repo, Kjogvi.OrnithoRepo)
Application.put_env(:ornithologue, :prefix, nil)

# In an umbrella-wide test run all suites share one VM, so another app's
# test_helper may already have defined and started this repo.
if !function_exported?(Kjogvi.OrnithoRepo, :__info__, 1) do
  defmodule Kjogvi.OrnithoRepo do
    use Ecto.Repo,
      otp_app: :ornithologue,
      adapter: Ecto.Adapters.Postgres

    use Scrivener
  end

  _ = Ecto.Adapters.Postgres.storage_up(Kjogvi.OrnithoRepo.config())

  opts = [strategy: :one_for_one, name: OrnithologueTest.Supervisor]
  Supervisor.start_link([Kjogvi.OrnithoRepo], opts)
end

# Bootstrap the Ornitho tables; both Ecto.Migrator and Ornitho.Migrations
# version tracking make this a no-op when already migrated. The migrator
# needs a non-sandboxed connection.
defmodule OrnithologueTest.Migration do
  use Ecto.Migration

  def up, do: Ornitho.Migrations.up(version: 1)
  def down, do: Ornitho.Migrations.down(version: 1)
end

Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :auto)

{:ok, _, _} =
  Ecto.Migrator.with_repo(
    Kjogvi.OrnithoRepo,
    &Ecto.Migrator.run(&1, [{1, OrnithologueTest.Migration}], :up, all: true)
  )

ExUnit.start()

ExUnit.after_suite(fn _ ->
  Application.put_env(:ornithologue, :repo, previous_repo)
  Application.put_env(:ornithologue, :prefix, previous_prefix)
end)

Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :manual)
