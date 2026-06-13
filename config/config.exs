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

# Configure the mailer
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

# Configure the endpoint
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
  version: "0.28.0",
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
  version: "4.3.0",
  kjogvi_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/kjogvi_web", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :scrivener_phoenix,
  window: 2,
  template: KjogviWeb.Scrivener.Phoenix.Template

# ex_aws S3 — IMAGES.
#
# The global ex_aws config is the IMAGE storage profile: waffle reads only the
# global ex_aws env (it accepts no per-call credentials/region), so whatever
# images need must live here. Other S3 consumers that call ExAws.request/2
# directly (e.g. the taxonomy importer) pass their own profile as a per-request
# override and do not rely on this global config for credentials.
config :ex_aws,
  http_client: ExAws.Request.Req

# Force HTTP/1 for S3: Req's shared Finch pool intermittently raises
# `:pool_not_available` when several requests negotiate HTTP/2 to S3 at once
# (e.g. waffle uploading all image variants concurrently). S3 fully supports
# HTTP/1, and Finch's HTTP/1 pooling handles the concurrency cleanly.
config :ex_aws, :req_opts,
  receive_timeout: 30_000,
  connect_options: [protocols: [:http1]]

# IMAGES

# Default storage is the local filesystem; prod switches to S3 in runtime.exs.
# The `storage_backend` string is persisted on each image so URLs keep
# resolving even when the running environment uses a different backend (e.g.
# a dev database imported from prod still points its images at prod S3).
config :waffle,
  storage: Waffle.Storage.Local,
  storage_dir_prefix: "apps/kjogvi_web/priv/static"

# `storage_backend` is the backend NEW uploads are written with in this env.
# `hosts` maps every backend an image might carry to the public host its URL is
# built against, so a database imported across environments still renders every
# image: a prod-S3 image opened on a local dev box resolves to the prod host,
# not the local one. `local` has no host — its files are served as a relative
# `/uploads/...` path by the endpoint's Plug.Static. The S3 hosts are filled in
# per environment (dev.exs / runtime.exs) from env vars.
config :kjogvi, :images,
  storage_backend: "local",
  hosts: %{
    "local" => nil,
    "s3_dev" => nil,
    "s3_prod" => nil
  }

# ORNITHOLOGUE

config :ornithologue, repo: Kjogvi.OrnithoRepo

config :ornithologue, Ornitho.Importer,
  legit_importers: [
    Ornitho.Importer.Ebird.V2023,
    Ornitho.Importer.Ebird.V2024,
    Ornitho.Importer.Ebird.V2025,
    Ornitho.Importer.AviList.V2025
  ]

config :ornithologue, Ornitho.StreamImporter,
  adapter: Ornitho.StreamImporter.LocalAdapter,
  path_prefix: "apps/ornithologue/priv"

# KJOGVI

# Compile time env var
config :kjogvi, multiuser: System.get_env("MULTI_USER") in ~w[1 true]

config :kjogvi, :cache, enabled: false

config :kjogvi, :email, registration_sender: {"Kjogvi User Management", "users@kjogvi.local"}

config :kjogvi, Kjogvi.Legacy.Import,
  adapter: Kjogvi.Legacy.Adapters.Local,
  database: System.get_env("LEGACY_DATABASE"),
  port: String.to_integer(System.get_env("LEGACY_PORT") || "5432"),
  hostname: System.get_env("LEGACY_HOSTNAME") || "localhost",
  username: System.get_env("LEGACY_USERNAME"),
  password: System.get_env("LEGACY_PASSWORD"),
  image_storage_buckets: %{}

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
