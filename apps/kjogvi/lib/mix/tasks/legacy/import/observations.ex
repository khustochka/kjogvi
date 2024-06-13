defmodule Mix.Tasks.Legacy.Import.Observations do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    Kjogvi.Legacy.Import.perform_import(:observations)
  end
end
