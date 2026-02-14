defmodule Ornithologue.MixProject do
  use Mix.Project

  def project do
    [
      app: :ornithologue,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.16",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: "Ornithological taxonomy",
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :runtime_tools],
      mod: {Ornithologue.Application, []}
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
  defp elixirc_paths(:dev), do: ["lib", "scripts"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.12"},
      {:postgrex, "~> 0.22"},
      # For jsonb columns
      {:jason, "~> 1.0"},
      {:scrivener_ecto, "~> 3.0"},
      {:csv, "~> 3.0"},
      {:ex_aws, "~> 2.1"},
      {:ex_aws_s3, "~> 2.0"},
      {:req, "~> 0.5"},
      {:sweet_xml, "~> 0.6"},
      {:configparser_ex, "~> 5.0", only: :dev},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.15", only: [:test], runtime: false},
      {:ex_machina, "~> 2.8", only: :test},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get"]
    ]
  end
end
