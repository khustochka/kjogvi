defmodule OrnithoWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      OrnithoWeb.Telemetry,
      # Start a worker by calling: OrnithoWeb.Worker.start_link(arg)
      # {OrnithoWeb.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: OrnithoWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
