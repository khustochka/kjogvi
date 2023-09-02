defmodule Mix.Tasks.Legacy.Import.Locations do
  @moduledoc false

  use Mix.Task

  def run(_args) do
    Mix.Task.run("app.start")
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")
    results = Postgrex.query!(pid, "SELECT * FROM loci ORDER BY id", [])

    columns = results.columns |> Enum.map(&String.to_atom/1)

    locations =
      for row <- results.rows do
        Enum.zip(columns, row)
        |> Enum.into(%{})
        |> convert_ancestry
        |> transform_keys
      end

    Kjogvi.Repo.insert_all(Kjogvi.Birding.Location, locations)

    Kjogvi.Repo.query!("SELECT setval('locations_id_seq', (SELECT MAX(id) FROM locations));")
  end

  defp convert_ancestry(%{ancestry: nil} = loc) do
    %{loc | ancestry: []}
  end

  defp convert_ancestry(%{ancestry: ""} = loc) do
    %{loc | ancestry: []}
  end

  defp convert_ancestry(%{ancestry: ancestry_str} = loc) do
    ancestors =
      ancestry_str
      |> String.split("/")
      |> Enum.map(&String.to_integer/1)

    %{loc | ancestry: ancestors}
  end

  defp transform_keys(
         %{five_mile_radius: is_5mr, loc_type: loc_type, patch: is_patch, private_loc: is_private} =
           loc
       ) do
    location_type =
      case loc_type do
        "" -> nil
        _ -> loc_type
      end

    time = DateTime.utc_now()

    loc
    |> Map.drop([
      :five_mile_radius,
      :loc_type,
      :patch,
      :private_loc,
      :ebird_location_id,
      :name_ru,
      :name_uk
    ])
    |> Map.put(:is_5mr, is_5mr)
    |> Map.put(:location_type, location_type)
    |> Map.put(:is_patch, is_patch)
    |> Map.put(:is_private, is_private)
    |> Map.put(:inserted_at, time)
    |> Map.put(:updated_at, time)
  end
end
