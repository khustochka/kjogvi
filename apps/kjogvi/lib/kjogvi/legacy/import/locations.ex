defmodule Kjogvi.Legacy.Import.Locations do
  @moduledoc false

  import Ecto.Query

  alias Kjogvi.Repo
  alias Kjogvi.Geo.Location

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

    _ = Repo.insert_all(Kjogvi.Geo.Location, locations)

    _ = Repo.query!("SELECT setval('locations_id_seq', (SELECT MAX(id) FROM locations));")

    five_mr_loc =
      from(l in Kjogvi.Geo.Location, where: l.slug == "5mr")
      |> preload(:special_child_locations)
      |> Repo.one()

    five_mr_children =
      from(l in Kjogvi.Geo.Location, where: l.slug in ^five_mr_slugs)
      |> Repo.all()

    five_mr_loc
    |> Ecto.Changeset.change(%{special_child_locations: five_mr_children})
    |> Repo.update()

    arabat_loc =
      from(l in Kjogvi.Geo.Location, where: l.slug == "arabat_spit")
      |> preload(:special_child_locations)
      |> Repo.one()

    arabat_children =
      from(l in Kjogvi.Geo.Location, where: l.slug in ["arabatska_khersonska", "arabatska_krym"])
      |> Repo.all()

    arabat_loc
    |> Ecto.Changeset.change(%{special_child_locations: arabat_children})
    |> Repo.update()
  end

  def after_import do
    Location
    |> Repo.all()
    |> Enum.each(fn loc ->
      loc
      |> Location.set_public_location_changeset()
      |> Repo.update()
    end)
  end

  def truncate do
    _ = Repo.query!("TRUNCATE special_locations, locations CASCADE;")
    _ = Repo.query!("ALTER SEQUENCE locations_id_seq RESTART;")
    _ = Repo.query!("ALTER SEQUENCE special_locations_id_seq RESTART;")
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
        case loc_type do
          "" -> nil
          "subcountry" -> "region"
          "state" -> "region"
          "oblast" -> "region"
          _ -> loc_type
        end
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
      :cached_country_id
    ])
    |> Map.put(:is_5mr, loc.five_mile_radius)
    |> Map.put(:location_type, location_type)
    |> Map.put(:is_patch, loc.patch)
    |> Map.put(:is_private, loc.private_loc)
    |> Map.put(:cached_country_id, loc.cached_country_id)
    |> Map.put(:inserted_at, time)
    |> Map.put(:updated_at, time)
  end
end
