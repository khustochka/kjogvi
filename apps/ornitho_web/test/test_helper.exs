Application.put_env(:ornitho_web, Kjogvi.OrnithoRepo,
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: System.get_env("DATABASE_PORT", "5498"),
  username: System.get_env("DATABASE_USER", "kjogvi"),
  password: System.get_env("DATABASE_PASSWORD", "kjogvi"),
  database: "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2
)

# The host config is restored after the suite — umbrella-wide test runs
# share one VM across suites.
previous_repo = Application.get_env(:ornithologue, :repo)
previous_prefix = Application.get_env(:ornithologue, :prefix)

Application.put_env(:ornithologue, :repo, Kjogvi.OrnithoRepo)
Application.put_env(:ornithologue, :prefix, nil)

# In an umbrella-wide test run all suites share one VM, so another app's
# test_helper may already have defined and started this repo.
if !function_exported?(Kjogvi.OrnithoRepo, :__info__, 1) do
  defmodule Kjogvi.OrnithoRepo do
    use Ecto.Repo,
      otp_app: :ornitho_web,
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
defmodule OrnithoWebTest.Migration do
  use Ecto.Migration

  def up, do: Ornitho.Migrations.up(version: 1)
  def down, do: Ornitho.Migrations.down(version: 1)
end

Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :auto)

{:ok, _, _} =
  Ecto.Migrator.with_repo(
    Kjogvi.OrnithoRepo,
    &Ecto.Migrator.run(&1, [{1, OrnithoWebTest.Migration}], :up, all: true)
  )

Application.put_env(:ornitho_web, OrnithoWebTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "byRSu+biw0VoGmlLh9e7qDL9GzOOYSFF7qk9+DzHVwiCbw43umbQOekDmcyPLcRd",
  live_view: [signing_salt: "VJdZQEK4tfjtXQ+3Ior32wClz7KWqwom"],
  render_errors: [view: OrnithoWebTest.ErrorView],
  check_origin: false,
  pubsub_server: OrnithoWebTest.PubSub
)

defmodule OrnithoWebTest.ErrorView do
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end

defmodule OrnithoWebTest.Router do
  use Phoenix.Router
  import OrnithoWeb.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
  end

  scope "/", ThisWontBeUsed, as: :this_wont_be_used do
    pipe_through :browser

    ornitho_web("/taxonomy")
  end
end

defmodule OrnithoWebTest.Endpoint do
  use Phoenix.Endpoint, otp_app: :ornitho_web

  plug Plug.Session,
    store: :cookie,
    key: "_live_view_key",
    signing_salt: "M3bi3fuhwkhD3V/VFvNW6s2ODP04+3Mf"

  plug OrnithoWebTest.Router
end

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: OrnithoWebTest.PubSub, adapter: Phoenix.PubSub.PG2},
    OrnithoWebTest.Endpoint
  ],
  strategy: :one_for_one
)

ExUnit.start(exclude: :integration)

ExUnit.after_suite(fn _ ->
  Application.put_env(:ornithologue, :repo, previous_repo)
  Application.put_env(:ornithologue, :prefix, previous_prefix)
end)

Ecto.Adapters.SQL.Sandbox.mode(Kjogvi.OrnithoRepo, :manual)
