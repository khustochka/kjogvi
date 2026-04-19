defmodule Mix.Tasks.Legacy.Import.Cards do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    user = Kjogvi.Users.main_user!()

    Kjogvi.Legacy.Import.perform_import(:cards, user: user)
  end
end
