Logger.configure(level: :debug)

# _argv = System.argv()

Application.put_env(:ornitho_web, DemoWeb.OrnithoRepo,
  url: System.get_env("DATABASE_ORNITHO_URL"),
  hostname: System.get_env("DATABASE_ORNITHO_HOST", "localhost"),
  port: System.get_env("DATABASE_ORNITHO_PORT", "5498"),
  username: System.get_env("DATABASE_ORNITHO_USER", "kjogvi"),
  password: System.get_env("DATABASE_ORNITHO_PASSWORD", "kjogvi"),
  database: System.get_env("DATABASE_ORNITHO_NAME", "ornithologue_dev"),
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
)

defmodule DemoWeb.OrnithoRepo do
  use Ecto.Repo, otp_app: :ornitho_web, adapter: Ecto.Adapters.Postgres

  use Scrivener
end

Application.put_env(:ornithologue, :repo, DemoWeb.OrnithoRepo)

_ = Ecto.Adapters.Postgres.storage_up(DemoWeb.OrnithoRepo.config())

# {:ok, _} = Application.ensure_all_started(:ornithologue)

Supervisor.start_link([DemoWeb.OrnithoRepo], strategy: :one_for_one)

for repo <- [DemoWeb.OrnithoRepo] do
  {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
end

# Configures the endpoint
Application.put_env(:ornitho_web, DemoWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "HsxaPv+VXm1JucXuaysVuvP8CuZsPpTM0y4IxDag0eFp1HZzWoMYcUKXIYKnAYxF",
  live_view: [signing_salt: "SooO5k66WSs9Hx3nEh7Y1EiDe+LV9Hkr"],
  http: [port: System.get_env("PORT") || 4000],
  debug_errors: System.get_env("SHOW_ERROR_PAGES") not in ~w{true 1},
  check_origin: false,
  pubsub_server: Demo.PubSub,
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:ornitho_web, ~w(--watch)]},
    tailwind: {Tailwind, :install_and_run, [:ornitho_web, ~w(--watch)]}
  ],
  live_reload: [
    patterns: [
      ~r"dist/.*(js|css|png|jpeg|jpg|gif|svg)$",
      ~r"lib/ornitho_web/(live|views)/.*(ex)$",
      ~r"lib/ornitho_web/templates/.*(ex)$"
    ]
  ]
)

defmodule DemoWeb.PageController do
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, :index) do
    content(conn, """
    <h2>OrnithoWeb Demo</h2>
    <a href="/taxonomy">Open Taxonomy</a>
    """)
  end

  defp content(conn, content) do
    conn
    |> put_resp_header("content-type", "text/html")
    |> send_resp(200, "<!doctype html><html><body>#{content}</body></html>")
  end
end

defmodule DemoWeb.Router do
  use Phoenix.Router

  import Phoenix.LiveView.Router
  import OrnithoWeb.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_csp
  end

  scope "/" do
    pipe_through :browser
    get "/", DemoWeb.PageController, :index

    ornitho_web("/taxonomy",
      csp_nonce_assign_key: %{
        img: :img_csp_nonce,
        style: :style_csp_nonce,
        script: :script_csp_nonce
      }
    )
  end

  def put_csp(conn, _opts) do
    [img_nonce, style_nonce, script_nonce] =
      for _i <- 1..3, do: 16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    conn
    |> assign(:img_csp_nonce, img_nonce)
    |> assign(:style_csp_nonce, style_nonce)
    |> assign(:script_csp_nonce, script_nonce)
    |> put_resp_header(
      "content-security-policy",
      "default-src; script-src 'nonce-#{script_nonce}'; style-src-elem 'nonce-#{style_nonce}'; " <>
        "img-src 'nonce-#{img_nonce}' data: ; font-src data: ; connect-src 'self'; frame-src 'self' ;"
    )
  end
end

defmodule DemoWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :ornitho_web

  @session_options [
    store: :cookie,
    key: "_ornitho_web_key",
    signing_salt: "/VEDsdfsffMnp5",
    same_site: "Lax"
  ]

  socket "/live", Phoenix.LiveView.Socket,
    websocket: [connect_info: [session: @session_options]],
    longpoll: [connect_info: [session: @session_options]]

  socket "/phoenix/live_reload/socket", Phoenix.LiveReloader.Socket

  plug Phoenix.LiveReloader
  plug Phoenix.CodeReloader

  plug Plug.RequestId
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()

  plug Plug.Session, @session_options
  plug DemoWeb.Router
end

Application.ensure_all_started(:os_mon)
Application.put_env(:phoenix, :serve_endpoints, true)

Task.async(fn ->
  children = []

  children =
    children ++
      [
        {Phoenix.PubSub, [name: Demo.PubSub, adapter: Phoenix.PubSub.PG2]},
        DemoWeb.Endpoint
      ]

  {:ok, _} = Supervisor.start_link(children, strategy: :one_for_one)
  Process.sleep(:infinity)
end)
|> Task.await(:infinity)
