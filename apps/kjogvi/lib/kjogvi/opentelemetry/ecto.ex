defmodule Kjogvi.Opentelemetry.Ecto do
  def setup() do
    Application.fetch_env!(:kjogvi, :ecto_repos)
    |> Enum.each(fn repo ->
      repo_key = split_repo_key(repo)
      OpentelemetryEcto.setup(repo_key, default_opts(repo_key))
    end)
  end

  defp default_opts(repo_key) do
    [db_statement: :enabled, service_addon: service_addon(repo_key)]
  end

  defp split_repo_key(repo) do
    repo
    |> Module.split
    |> Enum.map(fn str ->
      str
      |> Macro.underscore()
      |> String.to_atom()
    end)
  end

  def service_addon([_ | rest]) do
    rest |> Enum.map(&Atom.to_string/1) |> Enum.join("-")
  end
end
