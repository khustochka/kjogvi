defmodule Kjogvi.Legacy.Import.LocationsTest do
  use Kjogvi.DataCase, async: true

  alias Kjogvi.Geo.Location
  alias Kjogvi.Legacy.Import.Locations
  alias Kjogvi.Repo

  import Ecto.Query

  @columns [
    "id",
    "slug",
    "name_en",
    "name_ru",
    "name_uk",
    "loc_type",
    "ancestry",
    "iso_code",
    "private_loc",
    "patch",
    "five_mile_radius",
    "lat",
    "lon",
    "public_index",
    "ebird_location_id",
    "cached_public_locus_id"
  ]

  defp row(overrides) do
    defaults = %{
      "id" => 0,
      "slug" => "",
      "name_en" => "",
      "name_ru" => nil,
      "name_uk" => nil,
      "loc_type" => "",
      "ancestry" => nil,
      "iso_code" => nil,
      "private_loc" => false,
      "patch" => false,
      "five_mile_radius" => false,
      "lat" => nil,
      "lon" => nil,
      "public_index" => nil,
      "ebird_location_id" => nil,
      "cached_public_locus_id" => nil
    }

    attrs = Map.merge(defaults, overrides)
    Enum.map(@columns, &Map.fetch!(attrs, &1))
  end

  describe "import/3" do
    test "links five-mile-radius locations as special_child_locations of the 5mr location" do
      rows = [
        row(%{"id" => 1, "slug" => "5mr", "name_en" => "5MR"}),
        row(%{"id" => 10, "slug" => "arabat_spit", "name_en" => "Arabat Spit"}),
        row(%{
          "id" => 2,
          "slug" => "home_patch",
          "name_en" => "Home Patch",
          "five_mile_radius" => true
        }),
        row(%{
          "id" => 3,
          "slug" => "nearby_park",
          "name_en" => "Nearby Park",
          "five_mile_radius" => true
        }),
        row(%{"id" => 4, "slug" => "far_away", "name_en" => "Far Away"})
      ]

      Locations.import(@columns, rows, [])

      five_mr =
        from(l in Location, where: l.slug == "5mr")
        |> preload(:special_child_locations)
        |> Repo.one()

      assert Enum.map(five_mr.special_child_locations, & &1.slug) |> Enum.sort() ==
               ["home_patch", "nearby_park"]
    end
  end
end
