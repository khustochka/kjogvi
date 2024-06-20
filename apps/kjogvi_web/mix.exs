defmodule KjogviWeb.MixProject do
  use Mix.Project

  def project do
    [
      app: :kjogvi_web,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:leex, :yecc] ++ Mix.compilers(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {KjogviWeb.Application, []},
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

  defp extra_apps(:default), do: [:logger, :runtime_tools]
  defp extra_apps(:test), do: extra_apps(:default)
  defp extra_apps(_), do: extra_apps(:default) ++ [:os_mon, :opentelemetry]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.14"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.0-rc.3", override: true},
      {:floki, ">= 0.30.0"},
      {:timex, "~> 3.0"},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.1.4",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:earmark, "~> 1.4", only: [:dev, :test]},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:kjogvi, in_umbrella: true},
      {:ornitho_web, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:scrivener_phoenix, ">= 0.0.0", scrivener_phoenix_opts()},
      {:excoveralls, "~> 0.15", only: [:test, :dev], runtime: false},
      {:opentelemetry, "~> 1.4"},
      {:opentelemetry_api, "~> 1.2"},
      {:opentelemetry_phoenix, "~> 1.2", opentelemetry_phoenix_opts()},
      {:opentelemetry_bandit, "~> 0.1", opentelemetry_bandit_opts()},
      {:opentelemetry_exporter, "~> 1.6"},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  def opentelemetry_phoenix_opts do
    if System.get_env("LOCAL_OTEL_LIBS") do
      [path: "../../../opentelemetry-erlang-contrib/instrumentation/opentelemetry_phoenix"]
    else
      [
        github: "khustochka/opentelemetry-erlang-contrib",
        branch: "integration",
        subdir: "instrumentation/opentelemetry_phoenix"
      ]
    end
  end

  def opentelemetry_bandit_opts do
    if System.get_env("LOCAL_OTEL_LIBS") do
      [path: "../../../opentelemetry-erlang-contrib/instrumentation/opentelemetry_bandit"]
    else
      [
        github: "khustochka/opentelemetry-erlang-contrib",
        branch: "integration",
        subdir: "instrumentation/opentelemetry_bandit"
      ]
    end
  end

  defp scrivener_phoenix_opts() do
    if System.get_env("LOCAL_SCRIVENER") do
      [path: "../../../scrivener_phoenix"]
    else
      [github: "khustochka/scrivener_phoenix", branch: "integration"]
    end
  end

  # Aliases are shortcuts or tasks specific to the current project.
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind kjogvi_web", "esbuild kjogvi_web"],
      "assets.deploy": [
        "tailwind kjogvi_web --minify",
        "esbuild kjogvi_web --minify",
        "phx.digest"
      ]
    ]
  end
end
