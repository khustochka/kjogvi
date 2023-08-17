defmodule Mix.Tasks.Legacy.Import do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("ecto.drop", ["-r", "Kjogvi.Repo"])
    Mix.Task.run("ecto.create", ["-r", "Kjogvi.Repo"])
    Mix.Task.run("ecto.migrate", ["-r", "Kjogvi.Repo"])
    Mix.Task.run("legacy.import.locations")
    Mix.Task.run("legacy.import.cards")
    Mix.Task.run("legacy.import.observations")
  end
end
