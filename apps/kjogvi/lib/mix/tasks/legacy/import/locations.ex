defmodule Mix.Tasks.Legacy.Import.Locations do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    Kjogvi.Legacy.Import.perform_import(:locations)
  end
end
