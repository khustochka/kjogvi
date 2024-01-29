defmodule Mix.Tasks.Legacy.Import.Prepare do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    Kjogvi.Legacy.Import.prepare_import()

    :ok
  end
end
