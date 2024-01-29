defmodule Kjogvi.Legacy.Adapters.Local do
  @moduledoc false

  @per_page 1000

  def init() do
    hostname = Kjogvi.Legacy.Import.config()[:hostname] || "localhost"
    database = Kjogvi.Legacy.Import.config()[:database]
    {:ok, pid} = Postgrex.start_link(hostname: hostname, database: database)

    pid
  end

  def fetch_page(:locations, pid, page) do
    Postgrex.query!(
      pid,
      "SELECT * FROM loci ORDER BY id LIMIT #{@per_page} OFFSET #{@per_page * (page - 1)}",
      []
    )
  end

  def fetch_page(:cards, pid, page) do
    Postgrex.query!(
      pid,
      "SELECT * FROM cards ORDER BY id LIMIT #{@per_page} OFFSET #{@per_page * (page - 1)}",
      []
    )
  end

  def fetch_page(:observations, pid, page) do
    Postgrex.query!(
      pid,
      """
      SELECT observations.*, taxa.ebird_code
      FROM observations
      LEFT OUTER JOIN taxa ON taxa.id = taxon_id
      ORDER BY id
      LIMIT #{@per_page}
      OFFSET #{@per_page * (page - 1)}
      """,
      []
    )
  end
end
