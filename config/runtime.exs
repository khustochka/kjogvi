import Config

maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

config :kjogvi, Kjogvi.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  # For machines with several cores, consider starting multiple pools of `pool_size`
  # pool_count: 4,
  socket_options: maybe_ipv6

config :kjogvi, Kjogvi.OrnithoRepo,
  url: System.get_env("DATABASE_ORNITHO_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  # For machines with several cores, consider starting multiple pools of `pool_size`
  # pool_count: 4,
  socket_options: maybe_ipv6

config :kjogvi_web, KjogviWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4000"))]

if config_env() == :dev && System.get_env("BIND_PUBLIC") in ~w(true 1) do
  config :kjogvi_web, KjogviWeb.Endpoint, http: [ip: {0, 0, 0, 0}]
end

# Opentelemetry

cond do
  config_env() == :dev && System.get_env("OTEL_EXPORTER_STDOUT") in ~w(true 1) ->
    config :opentelemetry,
      traces_exporter: {:otel_exporter_stdout, []}

  System.get_env("OTEL_EXPORTER_DISABLE") in ~w(true 1) ->
    config :opentelemetry, traces_exporter: :none

  System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") ->
    config :opentelemetry,
      span_processor: :batch,
      sampler: {:parent_based, %{root: {Kjogvi.Telemetry.Sampler, %{}}}},
      traces_exporter: {:opentelemetry_exporter, %{}}

  # NOTE: Below stopped working for unclear reason
  # traces_exporter: {Kjogvi.Opentelemetry.Exporter, []}

  true ->
    config :opentelemetry, traces_exporter: :none
end

# Also for dev
# config :opentelemetry_exporter,
#   otlp_protocol: :http_protobuf,
#   otlp_endpoint: "http://localhost:4318"

# Set env vars
# export OTEL_SERVICE_NAME=your-service-name
# export OTEL_EXPORTER_OTLP_ENDPOINT=https://api.honeycomb.io:443
# export OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=your-api-key"
# export OTEL_EXPORTER_OTLP_PROTOCOL=grpc
# export OTEL_EXPORTER_OTLP_COMPRESSION=gzip
# if System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") do
#   config :opentelemetry_exporter,
#     otlp_protocol: :grpc,
#     otlp_compression: :gzip,
#     otlp_endpoint: "https://api.honeycomb.io:443",
#     otlp_headers: [{"x-honeycomb-team", "your-api-key"}]
# end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  # Port in the URL can be different from the one the server runs on
  url_port = String.to_integer(System.get_env("PHX_PORT") || "80")

  config :kjogvi_web, KjogviWeb.Endpoint,
    url: [host: host, port: url_port],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      ip: {0, 0, 0, 0, 0, 0, 0, 0}
    ],
    server: System.get_env("PHX_SERVER") in ~w(true 1),
    secret_key_base: secret_key_base

  # ## Using releases
  #
  # If you are doing OTP releases, you need to instruct Phoenix
  # to start each relevant endpoint:
  #
  #     config :kjogvi_web, KjogviWeb.Endpoint, server: true
  #
  # Then you can assemble a release by calling `mix release`.
  # See `mix help release` for more information.

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :kjogvi_web, KjogviWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your config/prod.exs,
  # ensuring no data is ever sent via http, always redirecting to https:
  #
  #     config :kjogvi_web, KjogviWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Here is an example configuration for Mailgun:
  #
  #     config :kjogvi, Kjogvi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # Most non-SMTP adapters require an API client. Swoosh supports Req, Hackney,
  # and Finch out-of-the-box. This configuration is typically done at
  # compile-time in your config/prod.exs:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Req
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  config :kjogvi, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  if System.get_env("EMAIL_REGISTRATION_SENDER_EMAIL") do
    config :kjogvi, :email,
      registration_sender: {
        System.get_env("EMAIL_REGISTRATION_SENDER_EMAIL"),
        System.get_env("EMAIL_REGISTRATION_SENDER_EMAIL")
      }
  end

  config :kjogvi, Kjogvi.Mailer,
    adapter: Swoosh.Adapters.Logger,
    log_full_email: true

  # ORNITHOLOGUE IMPORTER

  # Not really needed now, since the import query was optimized
  config :ornithologue, Ornitho.Importer,
    import_timeout: String.to_integer(System.get_env("ORNITHO_IMPORTER_TIMEOUT", "60000"))

  # Taxonomy downloads use their own S3 profile, passed as a per-request ex_aws
  # override (the global ex_aws config is the image storage profile). Credentials
  # are optional: when unset, ex_aws falls back to the global chain / instance
  # role.
  config :ornithologue, Ornitho.StreamImporter,
    adapter: Ornitho.StreamImporter.S3Adapter,
    bucket: System.get_env("ORNITHO_IMPORTER_S3_BUCKET"),
    region: System.get_env("ORNITHO_IMPORTER_S3_REGION"),
    access_key_id: System.get_env("ORNITHO_IMPORTER_S3_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("ORNITHO_IMPORTER_S3_SECRET_ACCESS_KEY")

  # KJOGVI DATASETS

  # Curated dataset snapshots (common locations etc.) live on S3 in prod.
  # Credentials are optional: when unset, ex_aws falls back to the global
  # chain / instance role.
  config :kjogvi, Kjogvi.Datasets,
    adapter: Kjogvi.Datasets.S3Adapter,
    bucket: System.get_env("KJOGVI_DATASETS_BUCKET"),
    region: System.get_env("KJOGVI_DATASETS_REGION"),
    access_key_id: System.get_env("KJOGVI_DATASETS_ACCESS_KEY_ID"),
    secret_access_key: System.get_env("KJOGVI_DATASETS_SECRET_ACCESS_KEY")

  # KJOGVI Legacy Import

  config :kjogvi, Kjogvi.Legacy.Import,
    adapter: Kjogvi.Legacy.Adapters.Download,
    url: System.get_env("LEGACY_URL"),
    api_key: System.get_env("LEGACY_API_KEY")
end

case config_env() do
  :dev ->
    config :kjogvi, :cache, enabled: System.get_env("DEV_CACHING") in ~w(true 1)

  :prod ->
    config :kjogvi, :cache, enabled: true

  _ ->
    nil
end

# If setup code is not set, a new one will be generated on request to /setup,
# and printed to the logs.
config :kjogvi, :setup_code, System.get_env("SETUP_CODE")

config :kjogvi, Kjogvi.Legacy.Import, taxonomy_slug: System.get_env("LEGACY_TAXONOMY_SLUG")

config :kjogvi_web, :google_maps, api_key: System.get_env("GOOGLE_MAPS_API_KEY")

# IMAGES
#
# Two concepts are kept separate here:
#
#   * Storage PROFILES (`s3_prod`, `s3_dev`) describe a *destination* — bucket,
#     region, and public host. They are read in every environment so that a
#     database shared across environments (e.g. a prod dump opened on a dev box,
#     or restored to staging) renders every image: each image records the
#     profile it was uploaded with, and `Kjogvi.Images.url/2` builds its URL
#     from that profile's host. This is why both hosts must always be present.
#
#   * The UPLOAD target is which profile NEW uploads are written to, chosen by
#     `IMAGES_UPLOAD_TARGET` — one of the backend names `s3_prod`, `s3_dev`, or
#     `local`, matching the value persisted on each image. There is exactly ONE
#     set of upload credentials (`IMAGES_UPLOAD_S3_*`) — you only ever write to
#     one bucket from a given running environment. The cross-bucket behaviour
#     is entirely on the read side, via the host map above.
#
# Examples:
#   * dev box, local files:     IMAGES_UPLOAD_TARGET=local (the default)
#   * dev box, dev bucket:      IMAGES_UPLOAD_TARGET=s3_dev  + IMAGES_UPLOAD_S3_*
#   * staging (prod env),
#     uploads to dev bucket:    IMAGES_UPLOAD_TARGET=s3_dev  + IMAGES_UPLOAD_S3_*
#   * production:               IMAGES_UPLOAD_TARGET=s3_prod + IMAGES_UPLOAD_S3_*
#
# Test pins local storage in test.exs, so this block is skipped there.
if config_env() != :test do
  image_profiles = %{
    "s3_prod" => %{
      backend: "s3_prod",
      bucket: System.get_env("IMAGES_S3_PROD_BUCKET"),
      region: System.get_env("IMAGES_S3_PROD_REGION"),
      host: System.get_env("IMAGES_S3_PROD_HOST")
    },
    "s3_dev" => %{
      backend: "s3_dev",
      bucket: System.get_env("IMAGES_S3_DEV_BUCKET"),
      region: System.get_env("IMAGES_S3_DEV_REGION"),
      host: System.get_env("IMAGES_S3_DEV_HOST")
    }
  }

  # The host map carries every backend an image might be tagged with, so any
  # image resolves regardless of which environment is rendering it.
  config :kjogvi, :images,
    hosts: %{
      "local" => nil,
      "s3_dev" => image_profiles["s3_dev"].host,
      "s3_prod" => image_profiles["s3_prod"].host
    }

  upload_target =
    case System.get_env("IMAGES_UPLOAD_TARGET", "local") do
      t when t in ~w(s3_prod s3_dev local) ->
        t

      other ->
        raise "IMAGES_UPLOAD_TARGET must be one of s3_prod|s3_dev|local, got: #{inspect(other)}"
    end

  case upload_target do
    "local" ->
      # New uploads go to the local filesystem (waffle's default from
      # config.exs); nothing to configure here. Images still render from S3 if
      # the database carries s3_* backends.
      config :kjogvi, :images, storage_backend: "local"

    backend ->
      profile = image_profiles[backend]
      env_prefix = "IMAGES_#{String.upcase(backend)}"

      profile.bucket ||
        raise "IMAGES_UPLOAD_TARGET=#{backend} requires #{env_prefix}_BUCKET"

      config :kjogvi, :images, storage_backend: profile.backend

      config :waffle,
        storage: Waffle.Storage.S3,
        bucket: profile.bucket

      # Waffle reads only the GLOBAL ex_aws config (no per-call credentials or
      # region), so the upload profile must live there. The single upload
      # credential set pairs with the destination profile's region. Other
      # consumers (e.g. the taxonomy importer) override per request and don't
      # depend on this.
      # Instance role disabled. If not configured, it causes catastrophic failure.
      config :ex_aws,
        access_key_id: [
          {:system, "IMAGES_UPLOAD_S3_ACCESS_KEY_ID"}
          # :instance_role
        ],
        secret_access_key: [
          {:system, "IMAGES_UPLOAD_S3_SECRET_ACCESS_KEY"}
          # :instance_role
        ]

      config :ex_aws, :s3, region: profile.region
  end
end
