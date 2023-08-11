pg_url = System.get_env("PG_URL") || "postgres:postgres@127.0.0.1"

Application.put_env(:ornithologue, Ornitho.Repo,
  url: "ecto://#{pg_url}/ornithologue_test",
  pool: Ecto.Adapters.SQL.Sandbox
)

_ = Ecto.Adapters.Postgres.storage_up(Ornitho.Repo.config())

Application.put_env(:ornitho_web, OrnithoWebTest.Endpoint,
  url: [host: "localhost", port: 4000],
  secret_key_base: "Hu4qQN3iKzTV4fJxhorPQlA/osH9fAMtbtjVS58PFgfw3ja5Z18Q/WSNR9wP4OfW",
  live_view: [signing_salt: "hMegieSe"],
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
    signing_salt: "/VEDsdfsffMnp5"

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
