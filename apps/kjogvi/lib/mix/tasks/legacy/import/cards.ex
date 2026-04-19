defmodule Mix.Tasks.Legacy.Import.Cards do
  @moduledoc false

  use Mix.Task

  @requirements ["app.start"]

  def run(_args) do
    user = Kjogvi.Users.admins() |> Kjogvi.Repo.one!()

    Kjogvi.Legacy.Import.perform_import(:cards, user: user)
  end
end
