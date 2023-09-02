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

      columns = results.columns |> Enum.map(&String.to_atom/1)

      cards =
        for row <- results.rows do
          # time = DateTime.utc_now()

          Enum.zip(columns, row)
          |> Enum.into(%{})
          |> transform_keys
        end

      Kjogvi.Repo.insert_all(Kjogvi.Birding.Card, cards)

      Kjogvi.Repo.query!("SELECT setval('cards_id_seq', (SELECT MAX(id) FROM cards));")
    end
  end

  defp transform_keys(
         %{
           locus_id: loc_id,
           autogenerated: autogenerated,
           created_at: created_at,
           updated_at: updated_at,
           start_time: start_time
         } = card
       ) do
    {:ok, inserted_at} = DateTime.from_naive(created_at, "Etc/UTC")
    {:ok, update_time} = DateTime.from_naive(updated_at, "Etc/UTC")

    card
    |> Map.drop([:locus_id, :autogenerated, :created_at, :post_id])
    |> Map.put(:location_id, loc_id)
    |> Map.put(:legacy_autogenerated, autogenerated)
    |> Map.put(:inserted_at, inserted_at)
    |> Map.put(:updated_at, update_time)
    |> Map.put(:start_time, convert_start_time(start_time))
  end

  def convert_start_time(""), do: nil
  def convert_start_time(nil), do: nil

  def convert_start_time(str) do
    [hr, min] = String.split(str, ":")
    {:ok, time} = Time.new(String.to_integer(hr), String.to_integer(min), 0)
    time
  end
end
