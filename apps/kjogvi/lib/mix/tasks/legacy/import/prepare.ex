defmodule Mix.Tasks.Legacy.Import.Prepare do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    Kjogvi.Legacy.Import.Observations.truncate()
    Kjogvi.Legacy.Import.Cards.truncate()
    Kjogvi.Legacy.Import.Locations.truncate()

    :ok
  end
end
