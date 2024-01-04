defmodule Mix.Tasks.Legacy.Import do
  @moduledoc """
  Import legacy records.
  """

  use Mix.Task

  def run(_args) do
    Mix.Task.run("legacy.import.prepare")
    Mix.Task.run("legacy.import.locations")
    Mix.Task.run("legacy.import.cards")
    Mix.Task.run("legacy.import.observations")
  end
end
