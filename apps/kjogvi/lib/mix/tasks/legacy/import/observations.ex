defmodule Mix.Tasks.Legacy.Import.Observations do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    Kjogvi.Legacy.Import.import_observations()
  end
end
