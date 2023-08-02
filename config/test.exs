import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :ornitho_web, OrnithoWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "1XMI8u7qQMxqxIuprg1NQhz/50IjX3H45WZGXghEDwDRgrXssjo7ZaXD1gNjn714",
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
  hostname: "localhost",
  database: "ornithologue_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10
