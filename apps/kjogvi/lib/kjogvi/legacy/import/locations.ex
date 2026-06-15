defmodule Kjogvi.Legacy.Import.Locations do
  @moduledoc false

  import Ecto.Query

  alias Kjogvi.Legacy.Import.Utils
  alias Kjogvi.Repo
  alias Kjogvi.Geo.Location

  @min_start_seq 10_000

  def import(columns_str, rows, _opts) do
    columns = columns_str |> Enum.map(&String.to_atom/1)

    locations =
      for row <- rows do
        Enum.zip(columns, row)
        |> Map.new()
        |> convert_ancestry
        |> transform_keys
      end

    five_mr_slugs = for loc <- locations, loc.is_5mr, do: loc.slug
    locations = Enum.map(locations, &Map.delete(&1, :is_5mr))

    with {_, _} <- Repo.insert_all(Location, locations),
         {:ok, _} <-
           Repo.query(
             "SELECT setval('locations_id_seq', GREATEST(#{@min_start_seq}, (SELECT COALESCE(MAX(id), 0) FROM locations)));"
           ),
         {:ok, _} <- fill_in_5mr(five_mr_slugs),
         {:ok, _} <- fill_in_arabat_spit() do
      :ok
    end
  end

  defp fill_in_5mr(five_mr_slugs) do
    with five_mr_loc when not is_nil(five_mr_loc) <-
           from(l in Location, where: l.slug == "5mr")
           |> preload(:special_child_locations)
           |> Repo.one(),
         five_mr_children <-
           from(l in Location, where: l.slug in ^five_mr_slugs)
           |> Repo.all() do
      five_mr_loc
      |> Ecto.Changeset.change(%{special_child_locations: five_mr_children})
      |> Repo.update()
    end
  end

  defp fill_in_arabat_spit do
    with arabat_loc when not is_nil(arabat_loc) <-
           from(l in Location, where: l.slug == "arabat_spit")
           |> preload(:special_child_locations)
           |> Repo.one(),
         arabat_children <-
           from(l in Location, where: l.slug in ["arabatska_khersonska", "arabatska_krym"])
           |> Repo.all() do
      arabat_loc
      |> Ecto.Changeset.change(%{special_child_locations: arabat_children})
      |> Repo.update()
    end
  end

  def cleanup do
    Kjogvi.Repo.query("DELETE FROM locations WHERE import_source='legacy';")
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

  defp transform_keys(%{loc_type: loc_type, slug: slug} = loc) do
    location_type =
      if slug in ["5mr", "arabat_spit"] do
        "special"
      else
        Utils.blank_to_nil(loc_type)
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
      :name_uk,
      :cached_public_locus_id
    ])
    |> Map.put(:is_5mr, loc.five_mile_radius)
    |> Map.put(:location_type, location_type)
    |> Map.put(:is_private, loc.private_loc)
    |> Map.put(:cached_public_location_id, loc.cached_public_locus_id)
    |> Map.update(:iso_code, nil, &Utils.blank_to_nil/1)
    |> Map.put(:inserted_at, time)
    |> Map.put(:updated_at, time)
    |> Map.put(:import_source, :legacy)
  end
end
