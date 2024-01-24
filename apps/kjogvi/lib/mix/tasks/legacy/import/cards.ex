defmodule Mix.Tasks.Legacy.Import.Cards do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")

    %{rows: [[cards_num]]} = Postgrex.query!(pid, "SELECT count(id) FROM cards", [])

    for i <- 0..div(cards_num - 1, 1000) do
      results =
        Postgrex.query!(pid, "SELECT * FROM cards ORDER BY id LIMIT 1000 OFFSET #{1000 * i}", [])

      Kjogvi.Legacy.Import.Cards.import(results.columns, results.rows)
    end
  end
end
