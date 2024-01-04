defmodule Mix.Tasks.Legacy.Import.Prepare do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")

    _ = Kjogvi.Repo.query!("TRUNCATE observations, cards, special_locations, locations;")
    _ = Kjogvi.Repo.query!("ALTER SEQUENCE cards_id_seq RESTART;")
    _ = Kjogvi.Repo.query!("ALTER SEQUENCE observations_id_seq RESTART;")
    _ = Kjogvi.Repo.query!("ALTER SEQUENCE locations_id_seq RESTART;")
    _ = Kjogvi.Repo.query!("ALTER SEQUENCE special_locations_id_seq RESTART;")
    :ok
  end
end
