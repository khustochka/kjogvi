defmodule Ornithologue.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Ornitho.Repo, []}
      # Starts a worker by calling: Ornithologue.Worker.start_link(arg)
      # {Ornithologue.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ornithologue.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
