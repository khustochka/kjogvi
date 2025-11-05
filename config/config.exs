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

# Configure Mix tasks and generators
config :kjogvi,
  ecto_repos: [Kjogvi.Repo, Kjogvi.OrnithoRepo],
  generators: [timestamp_type: :utc_datetime_usec]

config :kjogvi, Kjogvi.Repo, migration_timestamps: [type: :utc_datetime_usec]

config :kjogvi, Kjogvi.OrnithoRepo, migration_timestamps: [type: :utc_datetime_usec]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :kjogvi, Kjogvi.Mailer, adapter: Swoosh.Adapters.Local

# This is needed for some mix tasks
config :kjogvi_web,
  ecto_repos: [Kjogvi.Repo, Kjogvi.OrnithoRepo],
  generators: [timestamp_type: :utc_datetime_usec, context_app: :kjogvi]

# Configures the endpoint
config :kjogvi_web, KjogviWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: KjogviWeb.ErrorHTML, json: KjogviWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Kjogvi.PubSub,
  live_view: [signing_salt: "2bJWIBy2"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.10",
  kjogvi_web: [
    args: ~w(
        js/app.js
        --bundle
        --target=es2022
        --outdir=../priv/static/assets/js
        --external:/fonts/*
        --external:/images/*
        --alias:@=.
      ),
    cd: Path.expand("../apps/kjogvi_web/assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.14",
  kjogvi_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/kjogvi_web", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :scrivener_phoenix,
  window: 2,
  template: KjogviWeb.Scrivener.Phoenix.Template

# ORNITHOLOGUE

config :ornithologue, repo: Kjogvi.OrnithoRepo

config :ornithologue, Ornitho.Importer,
  legit_importers: [
    Ornitho.Importer.Ebird.V2022,
    Ornitho.Importer.Ebird.V2023,
    Ornitho.Importer.Ebird.V2024,
    Ornitho.Importer.Ebird.V2025
  ]

config :ornithologue, Ornitho.StreamImporter,
  adapter: Ornitho.StreamImporter.LocalAdapter,
  path_prefix: "apps/ornithologue/priv"

# KJOGVI

# Compile time env var
config :kjogvi, multiuser: System.get_env("MULTI_USER") in ~w[1 true]

config :kjogvi, :cache, enabled: false

config :kjogvi, :email, registration_sender: {"Kjogvi User Management", "users@kjogvi.local"}

config :kjogvi, :legacy,
  adapter: Kjogvi.Legacy.Adapters.Local,
  database: System.get_env("LEGACY_DATABASE"),
  port: String.to_integer(System.get_env("LEGACY_PORT") || "5432"),
  hostname: System.get_env("LEGACY_HOSTNAME") || "localhost",
  username: System.get_env("LEGACY_USERNAME"),
  password: System.get_env("LEGACY_PASSWORD"),
  taxonomy_slug: System.fetch_env!("LEGACY_TAXONOMY_SLUG")

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
