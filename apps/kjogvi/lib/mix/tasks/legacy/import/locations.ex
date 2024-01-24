defmodule Mix.Tasks.Legacy.Import.Locations do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")
    results = Postgrex.query!(pid, "SELECT * FROM loci ORDER BY id", [])

    Kjogvi.Legacy.Import.Locations.import(results.columns, results.rows)
  end
end
