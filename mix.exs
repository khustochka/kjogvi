defmodule Kjogvi.Umbrella.MixProject do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      version: "0.1.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      dialyzer: [
        plt_add_deps: :app_tree,
        plt_add_apps: [:mix],
        flags: [
          :error_handling,
          :no_opaque,
          :unknown,
          :no_return,
          :missing_return
        ]
      ],
      test_coverage: [tool: ExCoveralls],
      releases: [
        kjogvi: [
          applications: [kjogvi_web: :permanent, opentelemetry: :temporary]
        ]
      ]
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

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options.
  #
  # Dependencies listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp deps do
    [
      # Required to run "mix format" on ~H/.heex files from the umbrella root
      {:phoenix_live_view, ">= 0.0.0"},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  #
  # Aliases listed here are available only for this project
  # and cannot be accessed from applications inside the apps/ folder.
  defp aliases do
    [
      # run `mix setup` in all child apps
      setup: ["cmd mix setup"],
      "ecto.setup": ["ecto.create --quiet", "ecto.migrate --quiet"],
      lint: [
        "run --no-start -e 'IO.puts(\"Checking formatting...\")'",
        "format --check-formatted",
        "run --no-start -e 'IO.puts(\"Checking for unused dependencies...\")'",
        "deps.unlock --check-unused",
        "run --no-start -e 'IO.puts(\"Running credo...\")'",
        "credo --format oneline --ignore design,refactor,readability,consistency",
        "run --no-start -e 'IO.puts(\"Running dialyzer...\")'",
        "dialyzer --format dialyxir --quiet"
      ]
    ]
  end
end
