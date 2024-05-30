defmodule KjogviWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    :opentelemetry_cowboy.setup()
    OpentelemetryPhoenix.setup(adapter: :cowboy2)

    children = [
      # Start the Telemetry supervisor
      KjogviWeb.Telemetry,
      # Start a worker by calling: KjogviWeb.Worker.start_link(arg)
      # {KjogviWeb.Worker, arg}
      # Start to serve requests, typically the last entry
      KjogviWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: KjogviWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    KjogviWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
