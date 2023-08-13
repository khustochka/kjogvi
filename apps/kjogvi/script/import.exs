defmodule Import do
  require IEx

  def run do
    {:ok, pid} = Postgrex.start_link(hostname: "localhost", database: "quails_development")
    results = Postgrex.query!(pid, "SELECT * FROM loci", [])

    columns = results.columns |> Enum.map(&String.to_atom/1)

    locations = for row <- results.rows do
      time = DateTime.utc_now()

      Enum.zip(columns, row)
      |> Enum.into(%{})
      |> Map.drop([:ebird_location_id, :name_ru, :name_uk])
      |> convert_ancestry
      |> rename_keys
      |> Map.put(:inserted_at, time)
      |> Map.put(:updated_at, time)
    end

    _ = Ecto.Adapters.Postgres.storage_up(Kjogvi.Repo.config())

    for repo <- [Kjogvi.Repo] do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    Kjogvi.Repo.insert_all(Kjogvi.Schema.Location, locations)
  end

  def convert_ancestry(%{ancestry: nil} = loc) do
    %{loc | ancestry: []}
  end

  def convert_ancestry(%{ancestry: ""} = loc) do
    %{loc | ancestry: []}
  end

  def convert_ancestry(%{ancestry: ancestry_str} = loc) do
    ancestors =
      ancestry_str
      |> String.split("/")
      |> Enum.map(&String.to_integer/1)
    %{loc | ancestry: ancestors}
  end

  def rename_keys(%{five_mile_radius: is_5mr, loc_type: loc_type, patch: is_patch, private_loc: is_private} = loc) do
    location_type = case loc_type do
      "" -> nil
      _ -> loc_type
    end
    loc
    |> Map.drop([:five_mile_radius, :loc_type, :patch, :private_loc])
    |> Map.put(:is_5mr, is_5mr)
    |> Map.put(:location_type, location_type)
    |> Map.put(:is_patch, is_patch)
    |> Map.put(:is_private, is_private)
  end

end

Import.run
