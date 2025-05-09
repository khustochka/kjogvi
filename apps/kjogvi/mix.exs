defmodule Kjogvi.MixProject do
  use Mix.Project

  def project do
    [
      app: :kjogvi,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Kjogvi.Application, []},
      extra_applications: extra_apps(Mix.env())
    ]
  end

  def cli do
    [
      preferred_envs: [
        test: :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp extra_apps(:default), do: [:logger, :tls_certificate_check, :runtime_tools]
  defp extra_apps(:test), do: extra_apps(:default)
  # grpcbox is required for opentelemetry exporter using grpc (e.g. honeycomb)
  defp extra_apps(_), do: extra_apps(:default) ++ [:grpcbox, :opentelemetry]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bcrypt_elixir, "~> 3.0"},
      {:dns_cluster, "~> 0.2"},
      {:phoenix_pubsub, "~> 2.1"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_psql_extras, "~> 0.8"},
      {:postgrex, ">= 0.0.0"},
      {:cachex, "~> 4.0"},
      {:jason, "~> 1.2"},
      {:swoosh, "~> 1.18"},
      {:finch, "~> 0.13"},
      {:req, "~> 0.5"},
      {:http_cookie, "~> 0.9"},
      {:floki, ">= 0.30.0"},
      {:timex, github: "bitwalker/timex", ref: "cc649c7a586f1266b17d57aff3c6eb1a56116ca2"},
      {:scrivener_ecto, "~> 3.0"},
      {:nimble_options, "~> 1.1"},
      {:ornithologue, in_umbrella: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: [:test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:ecto_dev_logger, "~> 0.10", only: [:dev]},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_req, "~> 1.0"},
      {:opentelemetry_telemetry, "~> 1.1.1"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run #{__DIR__}/priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end
end
