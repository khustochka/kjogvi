import Config

config :phoenix, :json_library, Jason
config :phoenix, :stacktrace_depth, 20

config :logger, level: :warning
config :logger, :console, format: "[$level] $message\n"

if config_env() == :dev do
  config :esbuild,
    version: "0.19.11",
    default: [
      args:
        ~w(js/app.js --bundle --minify --target=es2017 --outdir=../dist/js --external:/fonts/* --external:/images/*),
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../../../deps", __DIR__)}
    ]

  # Configure tailwind (the version is required)
  config :tailwind,
    version: "3.4.0",
    default: [
      args: ~w(
        --config=tailwind.config.js
        --input=css/app.css
        --output=../dist/css/app.css
      ),
      cd: Path.expand("../assets", __DIR__)
    ]
end
