defmodule Mix.Tasks.Legacy.Import.Cards do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(args) do
    user = args[:user]

    Kjogvi.Legacy.Import.perform_import(:cards, user: user)
  end
end
