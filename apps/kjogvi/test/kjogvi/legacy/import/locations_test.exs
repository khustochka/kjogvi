defmodule Kjogvi.Legacy.Import.LocationsTest do
  # Not async: `Locations.import/3` calls `setval('locations_id_seq', ...)`, a
  # non-transactional, database-global side effect the SQL sandbox cannot
  # roll back or isolate. See Kjogvi.Legacy.Import.ChecklistsTest for details.
  use Kjogvi.DataCase, async: false

  alias Kjogvi.Geo.Location
  alias Kjogvi.Legacy.Import.Locations
  alias Kjogvi.Repo

  import Kjogvi.AccountsFixtures

  @columns [
    "id",
    "slug",
    "name_en",
    "loc_type",
    "ancestry",
    "iso_code",
    "private_loc",
    "five_mile_radius",
    "lat",
    "lon",
    "public_index"
  ]

  defp row(overrides) do
    defaults = %{
      "id" => 0,
      "slug" => "",
      "name_en" => "",
      "loc_type" => "",
      "ancestry" => nil,
      "iso_code" => nil,
      "private_loc" => false,
      "five_mile_radius" => false,
      "lat" => nil,
      "lon" => nil,
      "public_index" => nil
    }

    attrs = Map.merge(defaults, overrides)
    Enum.map(@columns, &Map.fetch!(attrs, &1))
  end

  defp run(rows, opts), do: Locations.import(@columns, rows, opts)

  setup do
    %{opts: [user: user_fixture()]}
  end

  describe "country / subdivision1 upsert onto ISO rows" do
    test "renumbers the matching ISO country to the legacy id and copies slug/lat/lon",
         %{opts: opts} do
      iso = insert(:country, iso_code: "US", slug: "us", name_en: "United States")

      run(
        [
          row(%{
            "id" => 42,
            "slug" => "usa",
            "name_en" => "Legacy USA",
            "loc_type" => "country",
            "iso_code" => "US",
            "lat" => "39.0",
            "lon" => "-98.0"
          })
        ],
        opts
      )

      refute Repo.get(Location, iso.id)
      moved = Repo.get!(Location, 42)
      assert moved.slug == "usa"
      assert Decimal.equal?(moved.lat, Decimal.new("39.0"))
      assert Decimal.equal?(moved.lon, Decimal.new("-98.0"))
      # ISO-sourced fields are left intact (only id/slug/lat/lon change).
      assert moved.name_en == "United States"
      assert moved.iso_code == "US"
      assert moved.user_id == nil
    end

    test "matches a subdivision1 on the full ISO code built from its country ancestor",
         %{opts: opts} do
      insert(:country, iso_code: "US", slug: "us")
      iso_tx = insert(:subdivision1, iso_code: "US-TX", slug: "us_tx", name_en: "Texas")

      run(
        [
          row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"}),
          row(%{
            "id" => 2,
            "slug" => "texas",
            "loc_type" => "subdivision1",
            "iso_code" => "TX",
            "ancestry" => "1"
          })
        ],
        opts
      )

      moved = Repo.get!(Location, 2)
      refute Repo.get(Location, iso_tx.id)
      assert moved.slug == "texas"
      assert moved.iso_code == "US-TX"
      assert moved.country_id == 1
    end

    test "repoints unvisited ISO subdivisions to the renumbered country's new id",
         %{opts: opts} do
      iso_us = insert(:country, iso_code: "US", slug: "us")
      # An ISO subdivision NOT present in the legacy data — must follow the country.
      iso_ak = insert(:subdivision1, iso_code: "US-AK", slug: "us_ak", country: iso_us)

      run(
        [
          row(%{"id" => 42, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"})
        ],
        opts
      )

      refute Repo.get(Location, iso_us.id)
      assert Repo.get!(Location, 42).iso_code == "US"
      # The unvisited Alaska keeps its own id but now points at the new country id.
      assert Repo.get!(Location, iso_ak.id).country_id == 42
    end

    test "repoints a linked eBird region to the renumbered country's new id",
         %{opts: opts} do
      iso_us = insert(:country, iso_code: "US", slug: "us")
      ebird = insert(:ebird_location, code: "US", location: iso_us)

      run(
        [
          row(%{"id" => 42, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"})
        ],
        opts
      )

      assert Repo.reload!(ebird).location_id == 42
    end

    test "resolves the country ancestor past a special continent above the country",
         %{opts: opts} do
      insert(:country, iso_code: "US", slug: "us")
      insert(:subdivision1, iso_code: "US-VA", slug: "us_va", name_en: "Virginia")

      run(
        [
          row(%{"id" => 140, "slug" => "north_america", "loc_type" => "special"}),
          row(%{
            "id" => 42,
            "slug" => "usa",
            "loc_type" => "country",
            "iso_code" => "US",
            "ancestry" => "140"
          }),
          row(%{
            "id" => 54,
            "slug" => "virginia",
            "loc_type" => "subdivision1",
            "iso_code" => "VA",
            "ancestry" => "140/42"
          })
        ],
        opts
      )

      moved = Repo.get!(Location, 54)
      assert moved.iso_code == "US-VA"
      assert moved.country_id == 42
    end

    test "fails when a country has no matching ISO row", %{opts: opts} do
      assert_raise RuntimeError, ~r/no matching ISO row/, fn ->
        run([row(%{"id" => 1, "loc_type" => "country", "iso_code" => "ZZ"})], opts)
      end
    end

    test "fails when a country has no iso_code", %{opts: opts} do
      assert_raise RuntimeError, ~r/no iso_code/, fn ->
        run([row(%{"id" => 1, "slug" => "blank", "loc_type" => "country"})], opts)
      end
    end
  end

  describe "hierarchy locations" do
    setup do
      insert(:country, iso_code: "US", slug: "us")
      :ok
    end

    test "derives level FKs from ancestry, owned by the importing user", %{opts: opts} do
      user = opts[:user]

      run(
        [
          row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"}),
          row(%{
            "id" => 5,
            "slug" => "dallas",
            "loc_type" => "city",
            "ancestry" => "1"
          }),
          row(%{
            "id" => 6,
            "slug" => "park",
            "loc_type" => "site",
            "ancestry" => "1/5"
          })
        ],
        opts
      )

      city = Repo.get!(Location, 5)
      assert city.location_type == :city
      assert city.country_id == 1
      assert city.user_id == user.id

      site = Repo.get!(Location, 6)
      assert site.country_id == 1
      assert site.city_id == 5
      assert site.user_id == user.id
    end

    test "preserves legacy ids and marks the import source", %{opts: opts} do
      run(
        [
          row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"}),
          row(%{"id" => 777, "slug" => "spot", "loc_type" => "site", "ancestry" => "1"})
        ],
        opts
      )

      site = Repo.get!(Location, 777)
      assert site.id == 777
      assert site.import_source == :legacy
    end
  end

  describe "specials inside the hierarchy" do
    test "creates the special, skips it in descendants' FKs, and links its direct children",
         %{opts: opts} do
      insert(:country, iso_code: "US", slug: "us")

      run(
        [
          row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"}),
          row(%{"id" => 2, "slug" => "region", "loc_type" => "special", "ancestry" => "1"}),
          row(%{"id" => 3, "slug" => "city", "loc_type" => "city", "ancestry" => "1/2"}),
          row(%{"id" => 4, "slug" => "site", "loc_type" => "site", "ancestry" => "1/2/3"})
        ],
        opts
      )

      special = Repo.get!(Location, 2) |> Repo.preload(:special_child_locations)
      assert special.location_type == :special
      # The special carries its own ancestor FKs (skipping special ancestors).
      assert special.country_id == 1

      # The special is outside the hierarchy: descendants' FKs jump over it.
      city = Repo.get!(Location, 3)
      assert city.country_id == 1
      assert city.subdivision1_id == nil
      assert city.subdivision2_id == nil

      site = Repo.get!(Location, 4)
      assert site.country_id == 1
      assert site.city_id == 3
      assert site.subdivision2_id == nil

      # Only the special's direct ancestry child (deepest ancestor == 2) is linked.
      assert Enum.map(special.special_child_locations, & &1.id) == [3]
    end
  end

  describe "5mr amalgamation" do
    setup do
      insert(:country, iso_code: "US", slug: "us")
      :ok
    end

    test "forces 5mr to special by slug and links five_mile_radius members",
         %{opts: opts} do
      run(
        [
          row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"}),
          # Forced special despite a non-special loc_type.
          row(%{"id" => 10, "slug" => "5mr", "name_en" => "5MR", "loc_type" => "site"}),
          row(%{
            "id" => 20,
            "slug" => "home_patch",
            "loc_type" => "site",
            "ancestry" => "1",
            "five_mile_radius" => true
          }),
          row(%{
            "id" => 21,
            "slug" => "nearby_park",
            "loc_type" => "site",
            "ancestry" => "1",
            "five_mile_radius" => true
          }),
          row(%{"id" => 22, "slug" => "far_away", "loc_type" => "site", "ancestry" => "1"})
        ],
        opts
      )

      five_mr = Repo.get!(Location, 10) |> Repo.preload(:special_child_locations)
      assert five_mr.location_type == :special

      assert five_mr.special_child_locations |> Enum.map(& &1.slug) |> Enum.sort() ==
               ["home_patch", "nearby_park"]
    end
  end

  describe "id sequence" do
    test "advances the sequence past @min_start_seq", %{opts: opts} do
      insert(:country, iso_code: "US", slug: "us")

      run([row(%{"id" => 1, "slug" => "usa", "loc_type" => "country", "iso_code" => "US"})], opts)

      next = Repo.insert!(%Location{slug: "fresh", name_en: "Fresh", location_type: :section})
      assert next.id >= 10_000
    end
  end
end
