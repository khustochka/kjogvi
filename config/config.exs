# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :kjogvi, Kjogvi.Mailer, adapter: Swoosh.Adapters.Local

config :kjogvi_web,
  generators: [context_app: :kjogvi]

# Configures the endpoint
config :kjogvi_web, KjogviWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: KjogviWeb.ErrorHTML, json: KjogviWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kjogvi.PubSub,
  live_view: [signing_salt: "eF5FDOBp"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.7",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2017 --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/kjogvi_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.1",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../apps/kjogvi_web/assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# ORNITHOLOGUE

config :ornithologue,
  ecto_repos: [Ornitho.Repo]

config :ornithologue, Ornitho.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
