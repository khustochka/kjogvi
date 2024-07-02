import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :kjogvi, Kjogvi.Repo,
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  port: System.get_env("DATABASE_PORT"),
  password: System.get_env("DATABASE_PASSWORD"),
  database: System.get_env("DATABASE_NAME", "kjogvi_test#{System.get_env("MIX_TEST_PARTITION")}"),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# nil username fails, no username uses the current user
db_user = System.get_env("DATABASE_USER")

if db_user do
  config :kjogvi, Kjogvi.Repo, username: db_user
end

config :kjogvi, Kjogvi.OrnithoRepo,
  hostname: System.get_env("DATABASE_ORNITHO_HOST", "localhost"),
  port: System.get_env("DATABASE_ORNITHO_PORT"),
  password: System.get_env("DATABASE_ORNITHO_PASSWORD"),
  database:
    System.get_env(
      "DATABASE_ORNITHO_NAME",
      "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}"
    ),
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# nil username fails, no username uses the current user
ornitho_db_user = System.get_env("DATABASE_ORNITHO_USER")

if ornitho_db_user do
  config :kjogvi, Kjogvi.OrnithoRepo, username: ornitho_db_user
end

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

# In test we don't send emails
config :kjogvi, Kjogvi.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
