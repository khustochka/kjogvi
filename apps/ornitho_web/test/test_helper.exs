Application.put_env(:ornithologue, Ornitho.Repo,
  url: System.get_env("ORNITHO_DATABASE_URL"),
  hostname: "localhost",
  database: "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
)

_ = Ecto.Adapters.Postgres.storage_up(Ornitho.Repo.config())

for repo <- [Ornitho.Repo] do
  {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
end

Application.put_env(:ornitho_web, OrnithoWebTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "byRSu+biw0VoGmlLh9e7qDL9GzOOYSFF7qk9+DzHVwiCbw43umbQOekDmcyPLcRd",
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

    ornitho_web "/taxonomy"
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

Application.stop(:ssh)
Application.unload(:ssh)

Supervisor.start_link(
  [
    {Phoenix.PubSub, name: OrnithoWebTest.PubSub, adapter: Phoenix.PubSub.PG2},
    OrnithoWebTest.Endpoint
  ],
  strategy: :one_for_one
)

ExUnit.start(exclude: :integration)
