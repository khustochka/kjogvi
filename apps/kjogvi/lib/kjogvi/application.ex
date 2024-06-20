defmodule Kjogvi.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  if Mix.env() == :dev do
    defp ecto_dev_logger do
      Ecto.DevLogger.install(Kjogvi.Repo, log_repo_name: true)
      Ecto.DevLogger.install(Kjogvi.OrnithoRepo, log_repo_name: true)
    end
  else
    defp ecto_dev_logger, do: nil
  end

  @impl true
  def start(_type, _args) do
    Kjogvi.Logger.install()
    ecto_dev_logger()

    Kjogvi.Opentelemetry.setup()

    children = [
      Kjogvi.Repo,
      Kjogvi.OrnithoRepo,
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
