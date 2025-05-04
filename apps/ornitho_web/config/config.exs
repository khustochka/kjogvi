import Config

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

config :logger, level: :warning
config :logger, :console, format: "[$level] $message\n"

if config_env() == :dev do
  config :esbuild,
    version: "0.25.3",
    ornitho_web: [
      args: ~w(
          js/app.js
          --bundle
          --minify
          --target=es2017
          --outdir=../dist/js
          --external:/fonts/*
          --external:/images/*
        ),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../../../deps", __DIR__)}
    ]

  # Configure tailwind (the version is required)
  config :tailwind,
    version: "4.1.5",
    ornitho_web: [
      args: ~w(
        --input=css/app.css
        --output=../dist/css/app.css
      ),
      cd: Path.expand("../assets", __DIR__)
    ]
end

config :ornithologue, Ornitho.Importer,
  legit_importers: [
    Ornitho.Importer.Ebird.V2022,
    Ornitho.Importer.Ebird.V2023,
    Ornitho.Importer.Ebird.V2024
  ]

config :ornithologue, Ornitho.StreamImporter,
  adapter: Ornitho.StreamImporter.LocalAdapter,
  path_prefix: "../ornithologue/priv"
