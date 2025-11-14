defmodule Kjogvi.Legacy.Adapters.Local do
  @moduledoc false

  @per_page 1000

  def init() do
    {:ok, pid} =
      Postgrex.start_link(
        hostname: Kjogvi.Legacy.Import.config()[:hostname],
        database: Kjogvi.Legacy.Import.config()[:database],
        port: Kjogvi.Legacy.Import.config()[:port],
        username: Kjogvi.Legacy.Import.config()[:username],
        password: Kjogvi.Legacy.Import.config()[:password]
      )

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
