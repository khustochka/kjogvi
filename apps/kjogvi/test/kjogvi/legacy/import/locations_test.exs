defmodule Kjogvi.Legacy.Import.LocationsTest do
  # Not async: `Locations.import/3` calls `setval('locations_id_seq', ...)`, a
  # non-transactional, database-global side effect the SQL sandbox cannot
  # roll back or isolate. See Kjogvi.Legacy.Import.CardsTest for details.
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Geo.Location
  alias Kjogvi.Legacy.Import.Locations
  alias Kjogvi.Repo

  import Ecto.Query
  import Kjogvi.AccountsFixtures

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

  # Disabled: `Locations.import/3` is a no-op until the legacy importer is
  # rebuilt onto the level-FK model (it relied on the dropped `ancestry` /
  # `cached_public_location_id` columns). See the module note.
  describe "import/3" do
    @describetag :skip
    setup do
      %{opts: [user: user_fixture()]}
    end

    test "links five-mile-radius locations as special_child_locations of the 5mr location",
         %{opts: opts} do
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

      Locations.import(@columns, rows, opts)

      five_mr =
        from(l in Location, where: l.slug == "5mr")
        |> preload(:special_child_locations)
        |> Repo.one()

      assert Enum.map(five_mr.special_child_locations, & &1.slug) |> Enum.sort() ==
               ["home_patch", "nearby_park"]
    end

    test "marks imported locations with the :legacy import source", %{opts: opts} do
      rows = [
        row(%{"id" => 1, "slug" => "5mr", "name_en" => "5MR"}),
        row(%{"id" => 10, "slug" => "arabat_spit", "name_en" => "Arabat Spit"})
      ]

      Locations.import(@columns, rows, opts)

      location = Repo.get_by!(Location, slug: "arabat_spit")
      assert location.import_source == :legacy
    end

    test "normalizes blank loc_type and iso_code to nil", %{opts: opts} do
      rows = [
        row(%{
          "id" => 5,
          "slug" => "blanks",
          "name_en" => "Blanks",
          "loc_type" => "  ",
          "iso_code" => "  "
        })
      ]

      Locations.import(@columns, rows, opts)

      location = Repo.get_by!(Location, slug: "blanks")
      assert location.location_type == nil
      assert location.iso_code == nil
    end

    test "trims and keeps a non-blank iso_code", %{opts: opts} do
      rows = [
        row(%{"id" => 6, "slug" => "withiso", "name_en" => "With ISO", "iso_code" => " UA "})
      ]

      Locations.import(@columns, rows, opts)

      location = Repo.get_by!(Location, slug: "withiso")
      assert location.iso_code == "UA"
    end

    test "assigns the importing user to ownable and untyped locations but not to common ones",
         %{opts: opts} do
      user = opts[:user]

      rows = [
        row(%{"id" => 20, "slug" => "canada", "name_en" => "Canada", "loc_type" => "country"}),
        row(%{"id" => 21, "slug" => "winnipeg", "name_en" => "Winnipeg", "loc_type" => "city"}),
        row(%{"id" => 22, "slug" => "highway-81", "name_en" => "Highway 81", "loc_type" => ""})
      ]

      Locations.import(@columns, rows, opts)

      assert Repo.get_by!(Location, slug: "canada").user_id == nil
      assert Repo.get_by!(Location, slug: "winnipeg").user_id == user.id
      assert Repo.get_by!(Location, slug: "highway-81").user_id == user.id
    end

    test "advances the id sequence past @min_start_seq for new locations", %{opts: opts} do
      rows = [
        row(%{"id" => 1, "slug" => "5mr", "name_en" => "5MR"}),
        row(%{"id" => 10, "slug" => "arabat_spit", "name_en" => "Arabat Spit"})
      ]

      Locations.import(@columns, rows, opts)

      next_location = Repo.insert!(%Location{slug: "fresh", name_en: "Fresh"})
      assert next_location.id >= 2_000
    end
  end
end
