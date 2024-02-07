defmodule OrnithoWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :ornitho_web,
      version: "0.1.0",
      build_path: "../../_build",
      # config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      # See OrnithoWeb.Application for explanation.
      # mod: {OrnithoWeb.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      # Deps
      {:phoenix_live_view, "~> 0.20.2"},
      {:phoenix, "~> 1.7.7"},
      {:phoenix_html, "~> 3.3"},
      {:ornithologue, in_umbrella: true},
      {:jason, "~> 1.2"},

      # Assets
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.1",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},

      # Dev/test
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:telemetry_metrics, "~> 0.6", only: [:dev, :test]},
      {:telemetry_poller, "~> 1.0", only: [:dev, :test]},
      {:gettext, "~> 0.20", only: [:dev, :test]},
      {:bandit, "~> 1.2", only: [:dev, :test]},
      {:excoveralls, "~> 0.15", only: [:test], runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:sobelow, "~> 0.12", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:floki, ">= 0.30.0", only: :test}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      dev: "run --no-halt dev.exs",
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind ornitho_web", "esbuild ornitho_web"]
      # "assets.deploy": [
      #   "tailwind ornitho_web --minify",
      #   "esbuild ornitho_web --minify",
      #   "phx.digest"
      # ]
    ]
  end
end
