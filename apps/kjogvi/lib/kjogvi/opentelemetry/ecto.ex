defmodule Kjogvi.Opentelemetry.Ecto do
  @moduledoc """
  Enables Ecto opentelemetry with customizations specific to the Kjogvi project.
  """

  @default_opts [db_statement: :enabled]

  def setup() do
    Application.fetch_env!(:kjogvi, :ecto_repos)
    |> Enum.each(fn repo ->
      repo_key = split_repo_key(repo)
      OpentelemetryEcto.setup(repo_key, @default_opts)
    end)
  end

  # defp default_opts(repo_key) do
  #   # Overwriting service name like this will only work in Datadog.
  #   # Other OTEL services just treat this as a regular tag and use the global service name.
  #   # NOTE: this is not needed anymore, since Datadog detects DB name.
  #   [db_statement: :enabled, additional_attributes: %{"service.name": service_name(repo_key)}]
  # end

  defp split_repo_key(repo) do
    repo
    |> Module.split()
    |> Enum.map(fn str ->
      str
      |> Macro.underscore()
      # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
      |> String.to_atom()
    end)
  end

  # defp service_name(repo_key) do
  #   repo_key |> Enum.map_join("-", &Atom.to_string/1)
  # end

  # defp service_addon([_ | rest]) do
  #   rest |> Enum.map(&Atom.to_string/1) |> Enum.join("-")
  # end
end
