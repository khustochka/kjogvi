defmodule Kjogvi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Kjogvi.Repo,
      {DNSCluster, query: Application.get_env(:kjogvi, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Kjogvi.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: Kjogvi.Finch}
      # Start a worker by calling: Kjogvi.Worker.start_link(arg)
      # {Kjogvi.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Kjogvi.Supervisor)
  end
end
