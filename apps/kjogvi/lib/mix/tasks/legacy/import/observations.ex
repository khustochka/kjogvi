defmodule Mix.Tasks.Legacy.Import.Observations do
  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
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

      columns = results.columns |> Enum.map(&String.to_atom/1)

      obs =
        for row <- results.rows do
          Enum.zip(columns, row)
          |> Enum.into(%{})
          |> transform_keys
        end

      Kjogvi.Repo.insert_all(Kjogvi.Schema.Observation, obs)
    end
  end

  defp transform_keys(%{ebird_code: "unrepbirdsp"} = obs) do
    %{obs | ebird_code: "bird1"}
    |> Map.put(:unreported, true)
    |> transform_keys
  end

  defp transform_keys(
         %{created_at: created_at, updated_at: updated_at, ebird_code: ebird_code} = obs
       ) do
    obs
    |> Map.drop([:created_at, :post_id, :taxon_id, :ebird_code])
    |> Map.put(:taxon_key, "/ebird/v2022/#{ebird_code}")
    |> Map.put(:inserted_at, convert_timestamp(created_at))
    |> Map.put(:updated_at, convert_timestamp(updated_at))
  end

  defp convert_timestamp(nil) do
    nil
  end

  defp convert_timestamp(time) do
    {:ok, converted} = DateTime.from_naive(time, "Etc/UTC")
    converted
  end
end
