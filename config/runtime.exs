import Config

maybe_ipv6 = if System.get_env("ECTO_IPV6") in ~w(true 1), do: [:inet6], else: []

config :kjogvi, Kjogvi.Repo,
  url: System.get_env("DATABASE_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6

config :kjogvi, Kjogvi.OrnithoRepo,
  url: System.get_env("DATABASE_ORNITHO_URL"),
  pool_size: String.to_integer(System.get_env("POOL_SIZE") || "10"),
  socket_options: maybe_ipv6

if config_env() == :dev && System.get_env("BIND_PUBLIC") in ~w(true 1) do
  config :kjogvi_web, KjogviWeb.Endpoint, http: [ip: {0, 0, 0, 0}, port: "4000"]
end

# Opentelemetry

cond do
  config_env() == :dev && System.get_env("OTEL_EXPORTER_STDOUT") in ~w(true 1) ->
    config :opentelemetry,
      traces_exporter: {:otel_exporter_stdout, []}

  System.get_env("OTEL_EXPORTER_OTLP_ENDPOINT") ->
    config :opentelemetry,
      span_processor: :batch,
      sampler: {:parent_based, %{root: {Kjogvi.Telemetry.Sampler, %{}}}},
      # traces_exporter: {:opentelemetry_exporter, []}
      traces_exporter: {Kjogvi.Opentelemetry.Exporter, []}

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
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: String.to_integer(System.get_env("PORT") || "4000")
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
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  #     config :kjogvi, Kjogvi.Mailer,
  #       adapter: Swoosh.Adapters.Mailgun,
  #       api_key: System.get_env("MAILGUN_API_KEY"),
  #       domain: System.get_env("MAILGUN_DOMAIN")
  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  #     config :swoosh, :api_client, Swoosh.ApiClient.Hackney
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

  config :kjogvi, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  # ORNITHOLOGUE IMPORTER

  config :ornithologue, Ornitho.Importer,
    import_timeout: String.to_integer(System.get_env("ORNITHO_IMPORTER_TIMEOUT", "30000"))

  config :ornithologue, Ornitho.StreamImporter,
    adapter: Ornitho.StreamImporter.S3Adapter,
    bucket: System.get_env("ORNITHO_IMPORTER_S3_BUCKET"),
    region: System.get_env("ORNITHO_IMPORTER_S3_REGION")

  # KJOGVI Legacy Import

  config :kjogvi, :legacy,
    adapter: Kjogvi.Legacy.Adapters.Download,
    url: System.get_env("LEGACY_URL"),
    api_key: System.get_env("LEGACY_API_KEY")
end
