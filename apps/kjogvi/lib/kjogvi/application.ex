defmodule Kjogvi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Kjogvi.Telemetry.setup()

    children = [
      Kjogvi.Repo,
      Kjogvi.Cache,
      {Kjogvi.Store.ChecklistPreload, name: Kjogvi.Store.ChecklistPreload},
      {DNSCluster, query: Application.get_env(:kjogvi, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: Kjogvi.PubSub},
      {Oban, Application.fetch_env!(:kjogvi, Oban)},
      {Task.Supervisor, name: Kjogvi.TaskSupervisor},
      Kjogvi.Server.ExclusiveTaskProcessor
      # Start a worker by calling: Kjogvi.Worker.start_link(arg)
      # {Kjogvi.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Kjogvi.Supervisor)
  end
end
