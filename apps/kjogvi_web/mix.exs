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
      elixir: "~> 1.16",
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

  defp extra_apps(:minimal), do: [:logger, :runtime_tools]
  defp extra_apps(:default), do: extra_apps(:minimal) ++ [:os_mon, :opentelemetry]
  defp extra_apps(:test), do: extra_apps(:minimal)
  defp extra_apps(:dev), do: extra_apps(:default) ++ [:observer, :wx]
  defp extra_apps(_), do: extra_apps(:default)

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.20"},
      {:phoenix_ecto, "~> 4.5"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.0.17"},
      {:timex, github: "bitwalker/timex", ref: "cc649c7a586f1266b17d57aff3c6eb1a56116ca2"},
      {:phoenix_live_dashboard, "~> 0.8.4"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:fontawesome,
       github: "FortAwesome/Font-Awesome",
       tag: "6.7.2",
       sparse: "svgs",
       app: false,
       compile: false,
       depth: 1},
      # {:earmark, "~> 1.4", only: [:dev, :test]},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:kjogvi, in_umbrella: true},
      {:ornitho_web, in_umbrella: true},
      {:jason, "~> 1.2"},
      {:bandit, "~> 1.5"},
      {:scrivener_phoenix, ">= 0.0.0", scrivener_phoenix_opts()},
      {:floki, ">= 0.30.0"},
      {:excoveralls, "~> 0.15", only: [:test, :dev], runtime: false},
      {:opentelemetry, "~> 1.5"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_phoenix, "~> 2.0.0", opentelemetry_phoenix_opts()},
      {:opentelemetry_bandit, "~> 0.2.0"},
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
        branch: "add-liveview-params",
        subdir: "instrumentation/opentelemetry_phoenix"
      ]
    end
  end

  defp scrivener_phoenix_opts() do
    if System.get_env("LOCAL_SCRIVENER") do
      [path: "../../../scrivener_phoenix"]
    else
      [github: "khustochka/scrivener_phoenix", branch: "fix-deprecated-link"]
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
