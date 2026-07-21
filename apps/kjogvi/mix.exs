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
      {:postgrex, "~> 0.22"},
      {:cachex, "~> 4.0"},
      {:csv, "~> 3.0"},
      {:oban, "~> 2.23"},
      # Fork of waffle that makes hackney optional.
      {:waffle, github: "khustochka/waffle", branch: "hackney-optional", override: true},
      {:waffle_ecto, "~> 0.0.12"},
      {:vix, "~> 0.31"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:jason, "~> 1.2"},
      {:swoosh, "~> 1.25"},
      {:req, "~> 0.6.1", override: true},
      {:http_cookie, "~> 0.10.0"},
      {:floki, ">= 0.30.0"},
      {:datix, "~> 0.3"},
      {:scrivener_ecto, "~> 3.0"},
      {:nimble_options, "~> 1.1"},
      {:ornithologue, in_umbrella: true},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: [:test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:ecto_dev_logger, "~> 0.10", only: [:dev]},
      {:opentelemetry, "~> 1.6"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_exporter, "~> 1.6"},
      {:opentelemetry_req, "~> 1.0"},
      {:opentelemetry_oban, "~> 1.2.0"},
      {:opentelemetry_telemetry, "~> 1.1.1"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # For Livebook
      {:vega_lite, "~> 0.1.6", only: [:dev]},
      {:kino_vega_lite, "~> 0.1.11", only: [:dev]},
      {:random_colour, "~> 0.1.0", only: [:dev]},
      {:plug, "~> 1.19", only: [:test]}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.load", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # Keep structure.sql in sync with the database after every schema change,
      # but only in dev — dumping the test database would clobber the committed file.
      "ecto.migrate": ["ecto.migrate", &dump_dev_structure/1],
      "ecto.rollback": ["ecto.rollback", &dump_dev_structure/1],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp dump_dev_structure(_args) do
    if Mix.env() == :dev, do: Mix.Task.run("ecto.dump")
  end
end
