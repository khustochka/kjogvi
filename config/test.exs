import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :kjogvi, Kjogvi.Repo,
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: System.get_env("DATABASE_PORT"),
  user: System.get_env("DATABASE_USER"),
  password: System.get_env("DATABASE_PASSWORD"),
  database: System.get_env("DATABASE_NAME", "kjogvi_test#{System.get_env("MIX_TEST_PARTITION")}"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :kjogvi_web, KjogviWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base:
    System.get_env("SECRET_KEY_BASE") ||
      "jLXo2VmGjoSu38kAI1A5a2G3KlSBPPqphTpCju+fXZmRX7qzcOT+ilFHuab6rsOy",
  server: false

# Print only warnings and errors during test (set DEBUG env var to print debug messages)
config :logger, level: if(System.get_env("DEBUG"), do: :debug, else: :warning)

# In test we don't send emails.
config :kjogvi, Kjogvi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# ORNITHOLOGUE

config :ornithologue, Ornitho.Repo,
  hostname: System.get_env("ORNITHO_DATABASE_HOST", "localhost"),
  port: System.get_env("ORNITHO_DATABASE_PORT"),
  user: System.get_env("ORNITHO_DATABASE_USER"),
  password: System.get_env("ORNITHO_DATABASE_PASSWORD"),
  database:
    System.get_env(
      "ORNITHO_DATABASE_NAME",
      "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
