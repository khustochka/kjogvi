defmodule Mix.Tasks.Legacy.Import.Cards do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    Kjogvi.Legacy.Import.perform_import(:cards)
  end
end
