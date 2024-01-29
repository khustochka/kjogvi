defmodule Mix.Tasks.Legacy.Import.Locations do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    Kjogvi.Legacy.Import.import_locations()
  end
end
