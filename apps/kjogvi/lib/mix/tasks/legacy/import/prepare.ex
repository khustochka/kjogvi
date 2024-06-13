defmodule Mix.Tasks.Legacy.Import.Prepare do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    Kjogvi.Legacy.Import.prepare_import()

    :ok
  end
end
