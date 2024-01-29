defmodule Kjogvi.Legacy.Import do
  @moduledoc false

  def run do
    prepare_import()
    import_locations()
    import_cards()
    import_observations()
  end

  def prepare_import do
    Kjogvi.Legacy.Import.Observations.truncate()
    Kjogvi.Legacy.Import.Cards.truncate()
    Kjogvi.Legacy.Import.Locations.truncate()

    :ok
  end

  def import_locations do
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")
    results = Postgrex.query!(pid, "SELECT * FROM loci ORDER BY id", [])

    Kjogvi.Legacy.Import.Locations.import(results.columns, results.rows)
  end

  def import_cards do
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")

    %{rows: [[cards_num]]} = Postgrex.query!(pid, "SELECT count(id) FROM cards", [])

    for i <- 0..div(cards_num - 1, 1000) do
      results =
        Postgrex.query!(pid, "SELECT * FROM cards ORDER BY id LIMIT 1000 OFFSET #{1000 * i}", [])

      Kjogvi.Legacy.Import.Cards.import(results.columns, results.rows)
    end
  end

  def import_observations do
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")

    %{rows: [[obs_num]]} = Postgrex.query!(pid, "SELECT count(id) FROM observations", [])

    for i <- 0..div(obs_num - 1, 1000) do
      results =
        Postgrex.query!(
          pid,
          """
          SELECT observations.*, taxa.ebird_code
          FROM observations
          LEFT OUTER JOIN taxa ON taxa.id = taxon_id
          ORDER BY id
          LIMIT 1000
          OFFSET #{1000 * i}
          """,
          []
        )

      Kjogvi.Legacy.Import.Observations.import(results.columns, results.rows)
    end
  end
end
